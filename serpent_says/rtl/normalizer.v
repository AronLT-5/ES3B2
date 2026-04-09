// ============================================================================
// Feature Normalizer + Int8 Quantizer (with per-window max subtraction)
// ============================================================================
// Two-pass normalization:
//   Pass 1: Scan all 256 features to find the maximum value
//   Pass 2: For each feature: int8 = clamp(round((feature - max) * scale + offset), -127, 127)
//
// The max subtraction makes hardware features relative (all <= 0),
// matching Python's librosa.power_to_db(mel, ref=np.max) convention.
//
// scale and offset are pre-computed from training statistics in log2 space.
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
    reg signed [15:0] scale_rom  [0:N_FEATURES-1];
    reg signed [15:0] offset_rom [0:N_FEATURES-1];
    initial begin
        $readmemh(SCALE_FILE,  scale_rom);
        $readmemh(OFFSET_FILE, offset_rom);
    end

    // ── FSM ──
    localparam S_IDLE     = 3'd0;
    localparam S_MAX_READ = 3'd1;  // Pass 1: read features to find max
    localparam S_MAX_CMP  = 3'd2;  // Pass 1: compare and update max
    localparam S_NORM_RD  = 3'd3;  // Pass 2: read feature for normalization
    localparam S_NORM_CAL = 3'd4;  // Pass 2: compute normalized int8
    localparam S_DONE     = 3'd5;

    reg [2:0] state;
    reg [8:0] feat_idx;

    // Pass 1: max tracking
    reg signed [15:0] feat_max;

    // Pass 2: registered inputs
    reg signed [15:0] feat_reg;
    reg signed [15:0] s_reg, o_reg;

    // Subtract max: (feature - feat_max) makes all values <= 0
    wire signed [15:0] feat_relative = feat_reg - feat_max;

    // Multiply: (feature - max) * scale  (Q8.8 × Q8.8 = Q16.16)
    wire signed [31:0] product = feat_relative * s_reg;
    // Round Q16.16 to Q16.8
    wire signed [23:0] scaled = (product + 32'sd128) >>> 8;
    // Add offset (Q8.8, sign-extended to Q16.8)
    wire signed [23:0] with_offset = scaled + {{8{o_reg[15]}}, o_reg};
    // Round Q16.8 to integer
    wire signed [15:0] result = (with_offset + 24'sd128) >>> 8;

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
            feat_max     <= -16'sd32768;
            s_reg        <= 0;
            o_reg        <= 0;
        end else begin
            done    <= 1'b0;
            int8_we <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        state        <= S_MAX_READ;
                        feat_idx     <= 0;
                        feature_addr <= 0;
                        feat_max     <= -16'sd32768;  // reset max
                        busy         <= 1'b1;
                    end
                end

                // ── Pass 1: Find maximum feature value ──
                S_MAX_READ: begin
                    feat_reg <= feature_in;
                    state    <= S_MAX_CMP;
                end

                S_MAX_CMP: begin
                    if (feat_reg > feat_max)
                        feat_max <= feat_reg;

                    if (feat_idx == N_FEATURES - 1) begin
                        feat_idx     <= 0;
                        feature_addr <= 0;
                        state        <= S_NORM_RD;
                    end else begin
                        feat_idx     <= feat_idx + 1;
                        feature_addr <= feat_idx[7:0] + 1;
                        state        <= S_MAX_READ;
                    end
                end

                // ── Pass 2: Normalize with max subtraction ──
                S_NORM_RD: begin
                    feat_reg <= feature_in;
                    s_reg    <= scale_rom[feat_idx[7:0]];
                    o_reg    <= offset_rom[feat_idx[7:0]];
                    state    <= S_NORM_CAL;
                end

                S_NORM_CAL: begin
                    int8_out  <= clamped;
                    int8_addr <= feat_idx[7:0];
                    int8_we   <= 1'b1;

                    if (feat_idx == N_FEATURES - 1) begin
                        state <= S_DONE;
                    end else begin
                        feat_idx     <= feat_idx + 1;
                        feature_addr <= feat_idx[7:0] + 1;
                        state        <= S_NORM_RD;
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
