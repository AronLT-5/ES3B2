// ============================================================================
// Dense Layer (MAC-based, Sequential)
// ============================================================================
// Computes: output[j] = activation(sum_i(input[i] * weight[i][j]) + bias[j])
//
// Sequential: processes one output neuron at a time.
// For each output neuron j, iterates over all inputs i and accumulates.
//
// Weights stored in .mem ROM: output-major, weight[j*IN_N + i] = W_from_input_i_to_output_j
// Bias stored in .mem ROM: bias[j]
//
// Activation: 0 = none, 1 = ReLU (clamp negative to 0)
//
// All arithmetic is int8 weights × int8 inputs → int32 accumulator,
// then bias (int32) is added, result scaled and clamped to int8 output.
// ============================================================================

module dense_layer #(
    parameter IN_N       = 256,
    parameter OUT_N      = 32,
    parameter ACTIVATION = 1,     // 0=none, 1=ReLU
    parameter SHIFT      = 7,     // Accumulator right-shift (from quantization params)
    parameter W_FILE     = "hidden_weights.mem",
    parameter B_FILE     = "hidden_bias.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    // Control
    input  wire        start,
    output reg         busy,
    output reg         done,
    // Input vector (read port)
    output reg  [7:0]  in_addr,
    input  wire signed [7:0] in_data,
    // Output vector (written as computed)
    output reg  signed [7:0] out_data,
    output reg  [7:0]  out_addr,
    output reg         out_we
);

    // ── Weight ROM ──
    // Stored as int8, output-major: address = j * IN_N + i
    localparam W_DEPTH = IN_N * OUT_N;
    (* rom_style = "block" *) reg signed [7:0] weight_rom [0:W_DEPTH-1];
    initial $readmemh(W_FILE, weight_rom);

    // ── Bias ROM ──
    // Stored as int32 (8 hex digits per entry)
    reg signed [31:0] bias_rom [0:OUT_N-1];
    initial $readmemh(B_FILE, bias_rom);

    // ── FSM ──
    localparam S_IDLE = 2'd0;
    localparam S_MAC  = 2'd1;  // Multiply-accumulate loop
    localparam S_OUT  = 2'd2;  // Add bias, activate, output
    localparam S_DONE = 2'd3;

    reg [1:0]  state;
    reg [7:0]  out_idx;        // Current output neuron (0..OUT_N-1)
    reg [8:0]  in_idx;         // Current input index (0..IN_N-1)
    reg signed [31:0] acc;     // Accumulator

    // Weight address
    wire [15:0] w_addr = out_idx * IN_N + in_idx[7:0];

    // Registered weight and input for multiply
    reg signed [7:0] w_reg, x_reg;
    wire signed [15:0] product = w_reg * x_reg;

    // Output scaling: accumulator is in int8×int8 = int16 scale, accumulated IN_N times
    // The bias is pre-scaled to match. We need to scale the final result to int8.
    // SHIFT is set per-layer from quantization parameters.

    wire signed [31:0] with_bias = acc + bias_rom[out_idx];
    wire signed [31:0] shifted   = with_bias >>> SHIFT;

    // Apply activation
    wire signed [31:0] activated = (ACTIVATION == 1 && shifted < 0) ? 32'sd0 : shifted;

    // Clamp to int8
    wire signed [7:0] clamped = (activated > 32'sd127)  ? 8'sd127 :
                                (activated < -32'sd127)  ? -8'sd127 :
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
                    // Pipeline: cycle N sets address, cycle N+1 reads data
                    // We accumulate the product from the previous cycle's read
                    if (in_idx > 0) begin
                        acc <= acc + product;
                    end

                    if (in_idx == IN_N) begin
                        // All inputs accumulated for this neuron
                        state <= S_OUT;
                    end else begin
                        // Read weight and input for current index
                        w_reg   <= weight_rom[w_addr[15:0]];
                        x_reg   <= in_data;
                        in_addr <= in_idx[7:0] + 1; // pre-fetch next
                        in_idx  <= in_idx + 1;
                    end
                end

                S_OUT: begin
                    // Output the result for this neuron
                    out_data <= clamped;
                    out_addr <= out_idx;
                    out_we   <= 1'b1;

                    if (out_idx == OUT_N - 1) begin
                        state <= S_DONE;
                    end else begin
                        // Move to next output neuron
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
