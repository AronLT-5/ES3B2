// ============================================================================
// Command Filter (confidence + margin threshold, 1.5s cooldown)
// ============================================================================
// Post-processes raw CNN classification with:
//   1. Confidence threshold: max logit must be >= CONF_THRESH
//   2. Margin threshold:     (max - second) must be >= MARGIN_THRESH
//      This prevents firing when two classes have similar scores,
//      which is when double-triggers typically occur.
//   3. Class filter: only left/right generate turns
//   4. Cooldown: suppress ALL detections for COOLDOWN_TICKS after a turn
//      (1.5s default — long enough to cover the tail of a spoken word)
//
// Approach inspired by MathWorks Speech Command Recognition FPGA example:
//   - ProbabilityThreshold -> CONF_THRESH (min logit to accept)
//   - DecisionTimeWindow   -> COOLDOWN_TICKS (suppression after trigger)
//   - FrameAgreement       -> MARGIN_THRESH (must clearly beat runner-up)
// ============================================================================

module command_filter #(
    parameter signed [7:0] CONF_THRESH   = 8'sd2,   // Min max-logit to accept
    parameter signed [7:0] MARGIN_THRESH = 8'sd3,   // Min margin (max - second)
    parameter COOLDOWN_TICKS = 24'd37_500_000,       // 1.5s at 25 MHz
    parameter VOTE_N         = 1,                    // Unused, kept for compat
    parameter VOTE_K         = 1                     // Unused, kept for compat
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        voice_mode_en,
    // KWS inference input
    input  wire [1:0]  kws_class_i,     // 0=left, 1=right, 2=other
    input  wire signed [7:0] kws_conf_i,    // Max logit
    input  wire signed [7:0] kws_second_i,  // Second-best logit
    input  wire        kws_valid_i,
    // Raw KWS output (for display/debug, always active)
    output reg  [1:0]  voice_kws_class,
    output reg  [7:0]  voice_kws_conf,
    output reg         voice_kws_valid,
    // Filtered turn output (only when voice_mode_en)
    output reg  [1:0]  voice_turn_req,
    output reg         voice_turn_valid,
    // Debug / info bar
    output reg  [1:0]  last_cmd,
    output reg  [7:0]  last_cmd_conf,
    output reg         ml_alive
);

    // Cooldown counter
    reg [25:0] cooldown_cnt;
    wire       cooldown_active = (cooldown_cnt > 0);

    // Margin computation
    wire signed [7:0] margin = kws_conf_i - kws_second_i;

    // ML alive toggle
    reg ml_toggle;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voice_kws_class  <= 2'd0;
            voice_kws_conf   <= 8'd0;
            voice_kws_valid  <= 1'b0;
            voice_turn_req   <= 2'd0;
            voice_turn_valid <= 1'b0;
            last_cmd         <= 2'd0;
            last_cmd_conf    <= 8'd0;
            ml_alive         <= 1'b0;
            ml_toggle        <= 1'b0;
            cooldown_cnt     <= 0;
        end else begin
            voice_kws_valid  <= 1'b0;
            voice_turn_valid <= 1'b0;

            // Decrement cooldown
            if (cooldown_cnt > 0)
                cooldown_cnt <= cooldown_cnt - 1;

            if (kws_valid_i) begin
                // Map internal class encoding to interface encoding
                case (kws_class_i)
                    2'd0: voice_kws_class <= 2'b01; // left
                    2'd1: voice_kws_class <= 2'b10; // right
                    default: voice_kws_class <= 2'b00; // other
                endcase
                voice_kws_conf  <= kws_conf_i;
                voice_kws_valid <= 1'b1;

                // Toggle ML alive indicator
                ml_toggle <= ~ml_toggle;
                ml_alive  <= ~ml_toggle;

                // Generate turn if:
                //   - voice mode enabled
                //   - not in cooldown
                //   - max logit >= CONF_THRESH
                //   - margin (max - second) >= MARGIN_THRESH
                //   - class is left or right (not other)
                if (voice_mode_en && !cooldown_active &&
                    kws_conf_i >= CONF_THRESH && margin >= MARGIN_THRESH) begin
                    if (kws_class_i == 2'd0) begin
                        voice_turn_req   <= 2'b01;
                        voice_turn_valid <= 1'b1;
                        cooldown_cnt     <= COOLDOWN_TICKS;
                        last_cmd         <= 2'b01;
                        last_cmd_conf    <= kws_conf_i;
                    end else if (kws_class_i == 2'd1) begin
                        voice_turn_req   <= 2'b10;
                        voice_turn_valid <= 1'b1;
                        cooldown_cnt     <= COOLDOWN_TICKS;
                        last_cmd         <= 2'b10;
                        last_cmd_conf    <= kws_conf_i;
                    end
                end
            end
        end
    end

endmodule
