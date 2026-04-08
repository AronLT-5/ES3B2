// ============================================================================
// Binary Dense Layer (BNN — replaces MAC with selective add/subtract)
// ============================================================================
// Computes: for each output neuron j:
//   acc = sum_i(input[i] * w_bin[i,j])  where w_bin in {-1, +1}
//   result = (acc * scale[j] + bias[j]) >>> FRAC_BITS
//
// Binary weight encoding: bit=1 means +1, bit=0 means -1
// So: acc += (bit ? +input : -input) for each input element
//
// Weights stored as packed bytes in .mem ROM (output-major):
//   For output neuron j, bytes at address j*BYTES_PER_NEURON .. (j+1)*BYTES_PER_NEURON-1
//   Bit ordering within byte: MSB = input[8k], LSB = input[8k+7]
//
// Scale: Q8.8 signed 16-bit per output neuron (folded BN + alpha)
// Bias:  Q16.8 signed 32-bit per output neuron (folded BN + alpha + layer bias)
//
// Activation: 0 = none, 1 = sign (output {-1,+1} as 1-bit: 1=+1, 0=-1)
//
// For sign activation, output is 1-bit per neuron packed into out_bits register.
// For no activation, output is clamped int8 per neuron.
// ============================================================================

module binary_dense_layer #(
    parameter IN_N           = 256,
    parameter OUT_N          = 128,
    parameter ACTIVATION     = 1,     // 0=none (int8 out), 1=sign (binary out)
    parameter FRAC_BITS      = 8,     // Fractional bits in Q8.8 scale
    parameter BYTES_PER_NEURON = 32,  // ceil(IN_N / 8)
    parameter W_FILE         = "hidden_weights_bin.mem",
    parameter SCALE_FILE     = "hidden_scale.mem",
    parameter BIAS_FILE      = "hidden_bias.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    // Control
    input  wire        start,
    output reg         busy,
    output reg         done,
    // Input vector (int8, read port — used when input is int8)
    output reg  [7:0]  in_addr,
    input  wire signed [7:0] in_data,
    // Binary input (used when input is binary from previous layer)
    input  wire [IN_N-1:0] in_bits,     // Not used for layer 1; used for layer 2
    input  wire        in_is_binary,     // 0 = int8 input, 1 = binary input
    // Output: int8 (when ACTIVATION=0) or binary packed (when ACTIVATION=1)
    output reg  signed [7:0] out_data,   // int8 output per neuron
    output reg  [7:0]  out_addr,
    output reg         out_we,
    // Binary output register (when ACTIVATION=1)
    output reg  [OUT_N-1:0] out_bits     // Packed binary output
);

    // ── Weight ROM (packed binary, stored as bytes) ──
    localparam W_DEPTH = BYTES_PER_NEURON * OUT_N;
    (* rom_style = "block" *) reg [7:0] weight_rom [0:W_DEPTH-1];
    initial $readmemh(W_FILE, weight_rom);

    // ── Scale ROM (Q8.8, signed 16-bit) ──
    reg signed [15:0] scale_rom [0:OUT_N-1];
    initial $readmemh(SCALE_FILE, scale_rom);

    // ── Bias ROM (Q16.8, signed 32-bit) ──
    reg signed [31:0] bias_rom [0:OUT_N-1];
    initial $readmemh(BIAS_FILE, bias_rom);

    // ── FSM ──
    localparam S_IDLE     = 3'd0;
    localparam S_ACC_INT8 = 3'd1;  // Accumulate for int8 inputs
    localparam S_ACC_BIN  = 3'd2;  // Accumulate for binary inputs (popcount)
    localparam S_SCALE    = 3'd3;  // Apply scale + bias
    localparam S_OUT      = 3'd4;  // Write output
    localparam S_DONE     = 3'd5;

    reg [2:0]  state;
    reg [7:0]  out_idx;           // Current output neuron (0..OUT_N-1)
    reg [8:0]  in_idx;            // Current input index (0..IN_N-1)
    reg signed [19:0] acc;        // Accumulator (needs headroom for 256 x int8)
    reg [2:0]  bit_pos;           // Bit position within current weight byte
    reg [7:0]  w_byte;            // Current weight byte from ROM

    // Weight ROM address for current neuron + input byte
    wire [15:0] w_rom_addr = out_idx * BYTES_PER_NEURON + (in_idx[8:3]);

    // Current weight bit (MSB first within byte)
    wire w_bit = w_byte[7 - in_idx[2:0]];

    // ── Scaling pipeline ──
    // After accumulation: result = (acc * scale + bias) >>> FRAC_BITS
    reg signed [15:0] s_reg;
    reg signed [31:0] b_reg;

    // acc is integer, scale is Q8.8 (16-bit), so acc*scale is Q_.8 (36-bit)
    // bias is Q16.8 (32-bit), so it aligns directly with the product
    wire signed [35:0] scaled = acc * s_reg;  // 20-bit * 16-bit = 36-bit, Q_.8
    wire signed [35:0] result_full = scaled + {{4{b_reg[31]}}, b_reg};  // sign-extend bias to 36 bits
    // Shift right by FRAC_BITS to get integer result
    wire signed [35:0] result_shifted = result_full >>> FRAC_BITS;

    // Clamp to int8
    wire signed [7:0] clamped = (result_shifted > 36'sd127)  ? 8'sd127 :
                                 (result_shifted < -36'sd127) ? -8'sd127 :
                                 result_shifted[7:0];

    // Sign activation: output bit = (result >= 0) ? 1 : 0
    wire sign_bit = ~result_full[35];  // MSB is sign: 0 = positive, 1 = negative

    // ── Popcount for binary-input mode ──
    // For binary inputs, XNOR between in_bits and weight bits, then popcount
    // This is done byte-by-byte to save logic
    reg [7:0] in_byte_bin;  // 8 bits of binary input
    wire [7:0] xnor_byte = ~(in_byte_bin ^ w_byte);  // XNOR: matching bits = 1
    // Popcount of 8 bits
    wire [3:0] pc8 = xnor_byte[0] + xnor_byte[1] + xnor_byte[2] + xnor_byte[3]
                   + xnor_byte[4] + xnor_byte[5] + xnor_byte[6] + xnor_byte[7];

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
            out_bits <= 0;
            w_byte   <= 0;
            bit_pos  <= 0;
            s_reg    <= 0;
            b_reg    <= 0;
            in_byte_bin <= 0;
        end else begin
            done   <= 1'b0;
            out_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        out_idx  <= 0;
                        in_idx   <= 0;
                        acc      <= 0;
                        busy     <= 1'b1;
                        in_addr  <= 0;
                        if (in_is_binary)
                            state <= S_ACC_BIN;
                        else
                            state <= S_ACC_INT8;
                        // Pre-load first weight byte
                        w_byte <= weight_rom[0];
                    end
                end

                // ── Int8 input accumulation (layer 1) ──
                // For each input: acc += w_bit ? +input : -input
                S_ACC_INT8: begin
                    // Load weight byte at byte boundaries
                    if (in_idx[2:0] == 3'd0 && in_idx < IN_N) begin
                        w_byte <= weight_rom[w_rom_addr];
                    end

                    if (in_idx > 0 && in_idx <= IN_N) begin
                        // Accumulate: add or subtract based on previous cycle's weight bit
                        // w_bit was valid for in_idx-1
                    end

                    if (in_idx < IN_N) begin
                        // Read weight bit and accumulate
                        if (w_bit)
                            acc <= acc + {{12{in_data[7]}}, in_data};  // Sign-extend and add
                        else
                            acc <= acc - {{12{in_data[7]}}, in_data};  // Sign-extend and subtract

                        in_addr <= in_idx[7:0] + 8'd1;  // Pre-fetch next input
                        in_idx  <= in_idx + 1;

                        // Pre-load next weight byte if crossing byte boundary
                        if (in_idx[2:0] == 3'd7) begin
                            w_byte <= weight_rom[out_idx * BYTES_PER_NEURON + (in_idx[8:3]) + 1];
                        end
                    end else begin
                        // Done with this neuron, apply scale
                        state <= S_SCALE;
                        s_reg <= scale_rom[out_idx];
                        b_reg <= bias_rom[out_idx];
                    end
                end

                // ── Binary input accumulation (layer 2) ──
                // Process 8 bits at a time using XNOR + popcount
                S_ACC_BIN: begin
                    if (in_idx < BYTES_PER_NEURON) begin
                        // Load weight byte
                        w_byte <= weight_rom[out_idx * BYTES_PER_NEURON + in_idx[7:0]];
                        // Extract 8 bits of binary input
                        // in_bits is packed: bit[0] = neuron 0, etc.
                        // We process 8 bits at a time
                        in_byte_bin <= in_bits[(in_idx[7:0]*8) +: 8];
                        in_idx <= in_idx + 1;
                        // Need one cycle delay for ROM read
                        if (in_idx > 0) begin
                            // Popcount: each matching bit contributes +1, non-matching -1
                            // So: contribution = 2*popcount - 8
                            acc <= acc + {{15{1'b0}}, pc8, 1'b0} - 20'sd8;
                        end
                    end else begin
                        // Final byte contribution
                        acc <= acc + {{15{1'b0}}, pc8, 1'b0} - 20'sd8;
                        state <= S_SCALE;
                        s_reg <= scale_rom[out_idx];
                        b_reg <= bias_rom[out_idx];
                    end
                end

                S_SCALE: begin
                    // One cycle for multiply
                    state <= S_OUT;
                end

                S_OUT: begin
                    if (ACTIVATION == 1) begin
                        // Sign activation: store bit
                        out_bits[out_idx] <= sign_bit;
                    end else begin
                        // No activation: output clamped int8
                        out_data <= clamped;
                        out_addr <= out_idx;
                        out_we   <= 1'b1;
                    end

                    if (out_idx == OUT_N - 1) begin
                        state <= S_DONE;
                    end else begin
                        out_idx <= out_idx + 1;
                        in_idx  <= 0;
                        acc     <= 0;
                        in_addr <= 0;
                        if (in_is_binary) begin
                            state  <= S_ACC_BIN;
                            w_byte <= weight_rom[(out_idx + 1) * BYTES_PER_NEURON];
                        end else begin
                            state  <= S_ACC_INT8;
                            w_byte <= weight_rom[(out_idx + 1) * BYTES_PER_NEURON];
                        end
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
