// ============================================================================
// Conv2D Layer (Sequential MAC, SAME padding, ReLU)
// ============================================================================
// Computes 2D convolution with 3x3 kernel, SAME padding, ReLU activation.
//
// Sequential: processes one output element at a time.
// For each output position (oh, ow, oc), iterates over all KH*KW*C_IN
// kernel elements, accumulating int8 * int8 -> int32.
//
// Feature map addressing (row-major, channel-last):
//   address = (row * WIDTH + col) * CHANNELS + ch
//
// Weight ROM layout (output-channel-major):
//   address = oc * (KH * KW * C_IN) + kh * (KW * C_IN) + kw * C_IN + ic
//
// Pipeline (matches dense_layer.v pattern):
//   Cycle N:   latch w_reg, x_reg from current addresses
//   Cycle N+1: accumulate product, advance to next kernel position
// ============================================================================

module conv2d_layer #(
    parameter IN_H   = 16,
    parameter IN_W   = 16,
    parameter C_IN   = 1,
    parameter C_OUT  = 16,
    parameter KH     = 3,
    parameter KW     = 3,
    parameter SHIFT  = 7,
    parameter W_FILE = "conv1_weights.mem",
    parameter B_FILE = "conv1_bias.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         busy,
    output reg         done,
    // Input feature map read port
    output reg  [15:0] in_addr,
    input  wire signed [7:0] in_data,
    // Output feature map write port
    output reg  signed [7:0] out_data,
    output reg  [15:0] out_addr,
    output reg         out_we
);

    localparam OUT_H = IN_H;
    localparam OUT_W = IN_W;
    localparam PAD   = KH / 2;
    localparam KERNEL_SIZE = KH * KW * C_IN;
    localparam W_DEPTH = C_OUT * KERNEL_SIZE;

    // Weight ROM
    (* rom_style = "block" *) reg signed [7:0] weight_rom [0:W_DEPTH-1];
    initial $readmemh(W_FILE, weight_rom);

    // Bias ROM
    reg signed [31:0] bias_rom [0:C_OUT-1];
    initial $readmemh(B_FILE, bias_rom);

    // FSM
    localparam S_IDLE  = 3'd0;
    localparam S_ADDR0 = 3'd1;  // Set first read address for new pixel
    localparam S_MAC   = 3'd2;  // Kernel MAC loop
    localparam S_LAST  = 3'd3;  // Accumulate final product
    localparam S_WRITE = 3'd4;  // Bias + shift + ReLU + write
    localparam S_DONE  = 3'd5;

    reg [2:0] state;

    // Output position
    reg [7:0] oh, ow, oc;

    // Kernel indices (separate counters, no division needed)
    reg [3:0] kh_r, kw_r;
    reg [7:0] ic_r;
    reg [15:0] k_cnt;  // Total kernel elements processed

    // MAC
    reg signed [31:0] acc;
    reg signed [7:0]  w_reg, x_reg;
    wire signed [15:0] product = w_reg * x_reg;

    // Current input coordinate (for reading)
    wire signed [8:0] cur_in_r = $signed({1'b0, oh}) + $signed({5'b0, kh_r}) - PAD;
    wire signed [8:0] cur_in_c = $signed({1'b0, ow}) + $signed({5'b0, kw_r}) - PAD;
    wire cur_oob = (cur_in_r < 0) || (cur_in_r >= IN_H) ||
                   (cur_in_c < 0) || (cur_in_c >= IN_W);

    // Current weight address
    wire [15:0] cur_w_addr = oc * KERNEL_SIZE + kh_r * (KW * C_IN) + kw_r * C_IN + ic_r;

    // Next kernel indices (combinational, for address pre-fetch)
    reg [3:0]  nxt_kh, nxt_kw;
    reg [7:0]  nxt_ic;

    always @(*) begin
        nxt_kh = kh_r;
        nxt_kw = kw_r;
        nxt_ic = ic_r;
        if (ic_r < C_IN - 1) begin
            nxt_ic = ic_r + 1;
        end else begin
            nxt_ic = 0;
            if (kw_r < KW - 1) begin
                nxt_kw = kw_r + 1;
            end else begin
                nxt_kw = 0;
                if (kh_r < KH - 1) begin
                    nxt_kh = kh_r + 1;
                end
            end
        end
    end

    // Next input coordinate (for pre-fetch)
    wire signed [8:0] nxt_in_r = $signed({1'b0, oh}) + $signed({5'b0, nxt_kh}) - PAD;
    wire signed [8:0] nxt_in_c = $signed({1'b0, ow}) + $signed({5'b0, nxt_kw}) - PAD;
    wire nxt_oob = (nxt_in_r < 0) || (nxt_in_r >= IN_H) ||
                   (nxt_in_c < 0) || (nxt_in_c >= IN_W);

    // Bias + shift + ReLU + clamp
    wire signed [31:0] with_bias = acc + bias_rom[oc];
    wire signed [31:0] shifted   = with_bias >>> SHIFT;
    wire signed [31:0] activated = (shifted < 0) ? 32'sd0 : shifted;
    wire signed [7:0]  clamped   = (activated > 32'sd127)  ? 8'sd127 :
                                   (activated < -32'sd127) ? -8'sd127 :
                                   activated[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy  <= 1'b0;
            done  <= 1'b0;
            out_we <= 1'b0;
            in_addr <= 0;
            out_data <= 0; out_addr <= 0;
            oh <= 0; ow <= 0; oc <= 0;
            kh_r <= 0; kw_r <= 0; ic_r <= 0;
            k_cnt <= 0;
            acc <= 0;
            w_reg <= 0; x_reg <= 0;
        end else begin
            done   <= 1'b0;
            out_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state <= S_ADDR0;
                        busy  <= 1'b1;
                        oh <= 0; ow <= 0; oc <= 0;
                        kh_r <= 0; kw_r <= 0; ic_r <= 0;
                        k_cnt <= 0;
                        acc <= 0;
                    end
                end

                // Set the first read address for this output element.
                // Data will be available on in_data next cycle (S_MAC).
                S_ADDR0: begin
                    if (!cur_oob)
                        in_addr <= cur_in_r[7:0] * (IN_W * C_IN)
                                 + cur_in_c[7:0] * C_IN + ic_r;
                    state <= S_MAC;
                end

                S_MAC: begin
                    // Latch weight and input for the current position
                    w_reg <= weight_rom[cur_w_addr];
                    x_reg <= cur_oob ? 8'sd0 : in_data;

                    // Accumulate product from previous iteration
                    if (k_cnt > 0)
                        acc <= acc + product;

                    k_cnt <= k_cnt + 1;

                    // Advance kernel indices
                    kh_r <= nxt_kh;
                    kw_r <= nxt_kw;
                    ic_r <= nxt_ic;

                    // Pre-fetch next input (uses nxt_* which are computed
                    // from the CURRENT kh_r/kw_r/ic_r before they update)
                    if (!nxt_oob)
                        in_addr <= nxt_in_r[7:0] * (IN_W * C_IN)
                                 + nxt_in_c[7:0] * C_IN + nxt_ic;

                    // Last kernel element?
                    if (k_cnt == KERNEL_SIZE - 1)
                        state <= S_LAST;
                end

                // Accumulate the final product
                S_LAST: begin
                    acc <= acc + product;
                    state <= S_WRITE;
                end

                S_WRITE: begin
                    out_data <= clamped;
                    out_addr <= oh * (OUT_W * C_OUT) + ow * C_OUT + oc;
                    out_we   <= 1'b1;

                    // Advance output position
                    if (oc < C_OUT - 1) begin
                        oc <= oc + 1;
                        kh_r <= 0; kw_r <= 0; ic_r <= 0;
                        k_cnt <= 0; acc <= 0;
                        state <= S_ADDR0;
                    end else if (ow < OUT_W - 1) begin
                        oc <= 0; ow <= ow + 1;
                        kh_r <= 0; kw_r <= 0; ic_r <= 0;
                        k_cnt <= 0; acc <= 0;
                        state <= S_ADDR0;
                    end else if (oh < OUT_H - 1) begin
                        oc <= 0; ow <= 0; oh <= oh + 1;
                        kh_r <= 0; kw_r <= 0; ic_r <= 0;
                        k_cnt <= 0; acc <= 0;
                        state <= S_ADDR0;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
