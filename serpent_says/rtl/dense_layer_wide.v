// ============================================================================
// Dense Layer — Wide Address (MAC-based, Sequential)
// ============================================================================
// Same as dense_layer.v but with 16-bit input address to support IN_N > 256
// (e.g., the CNN's 512 -> 32 hidden layer after flatten).
//
// Computes: output[j] = activation(sum_i(input[i] * weight[i][j]) + bias[j])
// ============================================================================

module dense_layer_wide #(
    parameter IN_N       = 512,
    parameter OUT_N      = 32,
    parameter ACTIVATION = 1,     // 0=none, 1=ReLU
    parameter SHIFT      = 7,
    parameter W_FILE     = "hidden_weights.mem",
    parameter B_FILE     = "hidden_bias.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         busy,
    output reg         done,
    // Input vector (read port) — 16-bit address for IN_N > 256
    output reg  [15:0] in_addr,
    input  wire signed [7:0] in_data,
    // Output vector
    output reg  signed [7:0] out_data,
    output reg  [7:0]  out_addr,
    output reg         out_we
);

    localparam W_DEPTH = IN_N * OUT_N;
    (* rom_style = "block" *) reg signed [7:0] weight_rom [0:W_DEPTH-1];
    initial $readmemh(W_FILE, weight_rom);

    reg signed [31:0] bias_rom [0:OUT_N-1];
    initial $readmemh(B_FILE, bias_rom);

    localparam S_IDLE = 2'd0;
    localparam S_MAC  = 2'd1;
    localparam S_OUT  = 2'd2;
    localparam S_DONE = 2'd3;

    reg [1:0]  state;
    reg [7:0]  out_idx;
    reg [15:0] in_idx;         // Wide enough for IN_N up to 65535
    reg signed [31:0] acc;

    wire [15:0] w_addr = out_idx * IN_N + in_idx[15:0];

    reg signed [7:0] w_reg, x_reg;
    wire signed [15:0] product = w_reg * x_reg;

    wire signed [31:0] with_bias = acc + bias_rom[out_idx];
    wire signed [31:0] shifted   = with_bias >>> SHIFT;
    wire signed [31:0] activated = (ACTIVATION == 1 && shifted < 0) ? 32'sd0 : shifted;
    wire signed [7:0]  clamped   = (activated > 32'sd127)  ? 8'sd127 :
                                   (activated < -32'sd127) ? -8'sd127 :
                                   activated[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            out_idx  <= 0;
            in_idx   <= 0;
            acc      <= 0;
            busy     <= 1'b0;
            done     <= 1'b0;
            in_addr  <= 0;
            out_data <= 0;
            out_addr <= 0;
            out_we   <= 1'b0;
            w_reg    <= 0;
            x_reg    <= 0;
        end else begin
            done   <= 1'b0;
            out_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state   <= S_MAC;
                        out_idx <= 0;
                        in_idx  <= 0;
                        acc     <= 0;
                        busy    <= 1'b1;
                        in_addr <= 0;
                    end
                end

                S_MAC: begin
                    if (in_idx > 0)
                        acc <= acc + product;

                    if (in_idx == IN_N) begin
                        state <= S_OUT;
                    end else begin
                        w_reg   <= weight_rom[w_addr[15:0]];
                        x_reg   <= in_data;
                        in_addr <= in_idx + 1;
                        in_idx  <= in_idx + 1;
                    end
                end

                S_OUT: begin
                    out_data <= clamped;
                    out_addr <= out_idx;
                    out_we   <= 1'b1;

                    if (out_idx == OUT_N - 1) begin
                        state <= S_DONE;
                    end else begin
                        out_idx <= out_idx + 1;
                        in_idx  <= 0;
                        acc     <= 0;
                        in_addr <= 0;
                        state   <= S_MAC;
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
