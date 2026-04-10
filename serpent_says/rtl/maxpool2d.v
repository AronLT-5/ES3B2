// ============================================================================
// MaxPool2D (2x2, stride 2)
// ============================================================================
// Reads a feature map of size IN_H x IN_W x CHANNELS and writes
// a pooled feature map of size (IN_H/2) x (IN_W/2) x CHANNELS.
//
// For each 2x2 spatial region, selects the maximum value per channel.
//
// Addressing (channel-last, row-major):
//   address = (row * WIDTH + col) * CHANNELS + ch
// ============================================================================

module maxpool2d #(
    parameter IN_H     = 16,
    parameter IN_W     = 16,
    parameter CHANNELS = 16
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

    localparam OUT_H = IN_H / 2;
    localparam OUT_W = IN_W / 2;

    // FSM
    localparam S_IDLE  = 3'd0;
    localparam S_READ0 = 3'd1;  // Fetch (0,0) element
    localparam S_READ1 = 3'd2;  // Fetch (0,1), latch (0,0)
    localparam S_READ2 = 3'd3;  // Fetch (1,0), latch (0,1)
    localparam S_READ3 = 3'd4;  // Fetch (1,1), latch (1,0)
    localparam S_WRITE = 3'd5;  // Compute max, write output
    localparam S_DONE  = 3'd6;

    reg [2:0] state;

    // Output position
    reg [7:0] ph, pw, ch;

    // Latched values for the 2x2 window
    reg signed [7:0] v0, v1, v2, v3;

    // Max computation
    wire signed [7:0] max01 = (v0 >= v1) ? v0 : v1;
    wire signed [7:0] max23 = (v2 >= v3) ? v2 : v3;
    wire signed [7:0] max_val = (max01 >= max23) ? max01 : max23;

    // Input base row/col for current pool window
    wire [7:0] base_row = ph * 2;
    wire [7:0] base_col = pw * 2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            busy  <= 1'b0;
            done  <= 1'b0;
            out_we <= 1'b0;
            in_addr <= 0;
            out_data <= 0; out_addr <= 0;
            ph <= 0; pw <= 0; ch <= 0;
            v0 <= 0; v1 <= 0; v2 <= 0; v3 <= 0;
        end else begin
            done   <= 1'b0;
            out_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        busy <= 1'b1;
                        ph <= 0; pw <= 0; ch <= 0;
                        state <= S_READ0;
                        // Pre-fetch (0,0) element: address for (base_row, base_col, ch)
                        in_addr <= 0;  // Will be set properly below
                    end
                end

                // 4-cycle read sequence for each 2x2 pool window
                S_READ0: begin
                    // Set address for (row+0, col+0, ch)
                    in_addr <= (base_row * IN_W + base_col) * CHANNELS + ch;
                    state <= S_READ1;
                end

                S_READ1: begin
                    // Set address for (row+0, col+1, ch)
                    in_addr <= (base_row * IN_W + base_col + 1) * CHANNELS + ch;
                    // Latch (row+0, col+0) — available from previous address
                    v0 <= in_data;
                    state <= S_READ2;
                end

                S_READ2: begin
                    // Set address for (row+1, col+0, ch)
                    in_addr <= ((base_row + 1) * IN_W + base_col) * CHANNELS + ch;
                    v1 <= in_data;
                    state <= S_READ3;
                end

                S_READ3: begin
                    // Set address for (row+1, col+1, ch)
                    in_addr <= ((base_row + 1) * IN_W + base_col + 1) * CHANNELS + ch;
                    v2 <= in_data;
                    state <= S_WRITE;
                end

                S_WRITE: begin
                    v3 <= in_data;
                    // Max will use v0,v1,v2 (latched) and in_data as v3
                    // But v3 is being set this cycle (non-blocking), so max_val
                    // uses the OLD v3. We need to handle this correctly.
                    // Solution: compute max inline with in_data as v3.
                    out_data <= (max01 >= ((v2 >= in_data) ? v2 : in_data)) ?
                                max01 : ((v2 >= in_data) ? v2 : in_data);
                    out_addr <= (ph * OUT_W + pw) * CHANNELS + ch;
                    out_we   <= 1'b1;

                    // Advance position
                    if (ch < CHANNELS - 1) begin
                        ch <= ch + 1;
                        state <= S_READ0;
                    end else if (pw < OUT_W - 1) begin
                        ch <= 0; pw <= pw + 1;
                        state <= S_READ0;
                    end else if (ph < OUT_H - 1) begin
                        ch <= 0; pw <= 0; ph <= ph + 1;
                        state <= S_READ0;
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
