// ============================================================================
// Command Filter
// ============================================================================
// Post-processes KWS inference output to produce gameplay-safe turn requests.
//
// Filtering:
//   1. Confidence threshold: reject classifications below CONF_THRESH
//   2. Class filter: only left/right generate turns (other/silence -> no turn)
//   3. Cooldown: suppress repeated detections for COOLDOWN_TICKS after a turn
//
// Repeated same-direction turns ARE allowed after cooldown expires.
// This is required for Snake gameplay where left-left or right-right
// sequences are valid and common.
//
// Output signals match the Serpent Says interface contract:
//   voice_kws_class[1:0]  - 00=other/silence, 01=left, 10=right
//   voice_kws_conf[7:0]   - Confidence value
//   voice_kws_valid        - Classification valid strobe
//   voice_turn_req[1:0]   - Filtered turn: 01=left, 10=right
//   voice_turn_valid       - Filtered turn valid strobe
// ============================================================================

module command_filter #(
    parameter CONF_THRESH    = 8'sd40,   // Minimum confidence (int8 logit threshold)
    parameter COOLDOWN_TICKS = 24'd500_000  // ~20 ms at 25 MHz (adjustable)
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        voice_mode_en,   // Switch: enable voice control
    // KWS inference input
    input  wire [1:0]  kws_class_i,     // 0=left, 1=right, 2=other
    input  wire signed [7:0] kws_conf_i,
    input  wire        kws_valid_i,
    // Raw KWS output (for display/debug, always active)
    output reg  [1:0]  voice_kws_class,
    output reg  [7:0]  voice_kws_conf,
    output reg         voice_kws_valid,
    // Filtered turn output (only when voice_mode_en)
    output reg  [1:0]  voice_turn_req,  // 01=left, 10=right
    output reg         voice_turn_valid,
    // Debug / info bar
    output reg  [1:0]  last_cmd,        // Last accepted command
    output reg  [7:0]  last_cmd_conf,   // Confidence of last accepted command
    output reg         ml_alive         // Toggles on each valid classification
);

    // Cooldown counter
    reg [23:0] cooldown_cnt;
    wire       cooldown_active = (cooldown_cnt > 0);

    // ML alive toggle
    reg ml_toggle;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            voice_kws_class <= 2'd0;
            voice_kws_conf  <= 8'd0;
            voice_kws_valid <= 1'b0;
            voice_turn_req  <= 2'd0;
            voice_turn_valid <= 1'b0;
            last_cmd        <= 2'd0;
            last_cmd_conf   <= 8'd0;
            ml_alive        <= 1'b0;
            ml_toggle       <= 1'b0;
            cooldown_cnt    <= 0;
        end else begin
            // Default: clear strobes
            voice_kws_valid  <= 1'b0;
            voice_turn_valid <= 1'b0;

            // Decrement cooldown
            if (cooldown_cnt > 0)
                cooldown_cnt <= cooldown_cnt - 1;

            if (kws_valid_i) begin
                // Map internal class encoding to interface encoding
                // Internal: 0=left, 1=right, 2=other
                // Interface: 00=other/silence, 01=left, 10=right
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

                // Generate filtered turn request
                if (voice_mode_en && !cooldown_active) begin
                    if (kws_class_i == 2'd0 && kws_conf_i >= CONF_THRESH) begin
                        // Left turn
                        voice_turn_req   <= 2'b01;
                        voice_turn_valid <= 1'b1;
                        cooldown_cnt     <= COOLDOWN_TICKS;
                        last_cmd         <= 2'b01;
                        last_cmd_conf    <= kws_conf_i;
                    end else if (kws_class_i == 2'd1 && kws_conf_i >= CONF_THRESH) begin
                        // Right turn
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
