// ============================================================================
// Feature Normalizer + Int8 Quantizer
// ============================================================================
// Combines per-feature normalization and int8 quantization into one step:
//   int8_out = clamp(round(feature * scale + offset), -127, 127)
//
// The scale and offset values are pre-computed in Python to combine:
//   normalized = (feature - mean) / std
//   int8 = round(normalized / input_scale * 127)
//
// Into a single: scale = 127 / (std * input_scale)
//                offset = -mean * scale
//
// Requires: norm_scale.mem, norm_offset.mem (256 entries each, signed hex16)
// ============================================================================

module normalizer #(
    parameter N_FEATURES   = 256,
    parameter SCALE_FILE   = "norm_scale.mem",
    parameter OFFSET_FILE  = "norm_offset.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    // Control
    input  wire        start,        // Pulse: begin normalization
    output reg         busy,
    output reg         done,         // Pulse: all features normalized
    // Input: raw log-mel features
    input  wire signed [15:0] feature_in,
    output reg  [7:0]  feature_addr, // Address to read feature (0..255)
    // Output: quantized int8 features
    output reg  signed [7:0]  int8_out,
    output reg  [7:0]  int8_addr,
    output reg         int8_we       // Write enable for output
);

    // ── Normalization coefficient ROMs ──
    // scale: Q8.8 signed fixed-point
    // offset: Q8.8 signed fixed-point
    reg signed [15:0] scale_rom  [0:N_FEATURES-1];
    reg signed [15:0] offset_rom [0:N_FEATURES-1];
    initial begin
        $readmemh(SCALE_FILE,  scale_rom);
        $readmemh(OFFSET_FILE, offset_rom);
    end

    // ── FSM ──
    localparam S_IDLE = 2'd0;
    localparam S_READ = 2'd1;  // Set address, wait for data
    localparam S_CALC = 2'd2;  // Multiply + clamp
    localparam S_DONE = 2'd3;

    reg [1:0] state;
    reg [8:0] feat_idx;

    // Registered inputs
    reg signed [15:0] feat_reg;
    reg signed [15:0] s_reg, o_reg;

    // Multiply: feature * scale (16 × 16 = 32 bits, Q8.8 × Q8.8 = Q16.16)
    wire signed [31:0] product = feat_reg * s_reg;
    // Extract integer part after adding offset (also Q8.8)
    // product is Q16.16, round >>8 to get Q16.8, add offset (Q8.8), round >>8
    wire signed [23:0] scaled = (product + 32'sd128) >>> 8; // Q16.8 with rounding
    wire signed [23:0] with_offset = scaled + {{8{o_reg[15]}}, o_reg}; // sign-extend offset
    wire signed [15:0] result = (with_offset + 24'sd128) >>> 8; // Q16.0 with rounding

    // Clamp to [-127, 127]
    wire signed [7:0] clamped = (result > 16'sd127) ? 8'sd127 :
                                (result < -16'sd127) ? -8'sd127 :
                                result[7:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            feat_idx     <= 0;
            busy         <= 1'b0;
            done         <= 1'b0;
            feature_addr <= 0;
            int8_out     <= 0;
            int8_addr    <= 0;
            int8_we      <= 1'b0;
            feat_reg     <= 0;
            s_reg        <= 0;
            o_reg        <= 0;
        end else begin
            done    <= 1'b0;
            int8_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state        <= S_READ;
                        feat_idx     <= 0;
                        feature_addr <= 0;
                        busy         <= 1'b1;
                    end
                end

                S_READ: begin
                    // Register feature data and coefficients
                    feat_reg <= feature_in;
                    s_reg    <= scale_rom[feat_idx[7:0]];
                    o_reg    <= offset_rom[feat_idx[7:0]];
                    state    <= S_CALC;
                end

                S_CALC: begin
                    // Output clamped int8 value
                    int8_out  <= clamped;
                    int8_addr <= feat_idx[7:0];
                    int8_we   <= 1'b1;

                    if (feat_idx == N_FEATURES - 1) begin
                        state <= S_DONE;
                    end else begin
                        feat_idx     <= feat_idx + 1;
                        feature_addr <= feat_idx[7:0] + 1;
                        state        <= S_READ;
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
