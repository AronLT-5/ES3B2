// ============================================================================
// Command Filter (with K-of-N temporal voting)
// ============================================================================
// Post-processes KWS inference output to produce gameplay-safe turn requests.
//
// Filtering:
//   1. Confidence threshold: reject classifications below CONF_THRESH
//   2. Class filter: only left/right generate turns (other/silence -> no turn)
//   3. K-of-N voting: require VOTE_K out of last VOTE_N classifications to
//      agree on the same direction before accepting (suppresses single-frame
//      spikes from noise or ambiguous speech)
//   4. Cooldown: suppress repeated detections for COOLDOWN_TICKS after a turn
//
// Repeated same-direction turns ARE allowed after cooldown expires.
//
// Output signals match the Serpent Says interface contract:
//   voice_kws_class[1:0]  - 00=other/silence, 01=left, 10=right
//   voice_kws_conf[7:0]   - Confidence value
//   voice_kws_valid        - Classification valid strobe
//   voice_turn_req[1:0]   - Filtered turn: 01=left, 10=right
//   voice_turn_valid       - Filtered turn valid strobe
// ============================================================================

module command_filter #(
    parameter CONF_THRESH    = 8'sd2,    // Minimum confidence (int8 logit threshold)
    parameter COOLDOWN_TICKS = 24'd12_500_000,  // 500ms at 25 MHz
    parameter VOTE_N         = 3,        // Voting window size
    parameter VOTE_K         = 2         // Required agreeing votes
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

    // ── Voting history: store last VOTE_N classifications ──
    // Each entry: 2-bit class (0=left, 1=right, 2=other, 3=unused)
    reg [1:0] vote_history [0:VOTE_N-1];
    integer vi;

    // Count votes for each class in the history window
    reg [3:0] left_votes, right_votes;
    integer ci;
    always @(*) begin
        left_votes  = 0;
        right_votes = 0;
        for (ci = 0; ci < VOTE_N; ci = ci + 1) begin
            if (vote_history[ci] == 2'd0) left_votes  = left_votes + 1;
            if (vote_history[ci] == 2'd1) right_votes = right_votes + 1;
        end
    end

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
            for (vi = 0; vi < VOTE_N; vi = vi + 1)
                vote_history[vi] <= 2'd2;  // Initialize to "other"
        end else begin
            // Default: clear strobes
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

                // Shift voting history and insert new classification
                for (vi = VOTE_N-1; vi > 0; vi = vi - 1)
                    vote_history[vi] <= vote_history[vi-1];

                // Only count confident classifications in voting
                if (kws_conf_i >= CONF_THRESH)
                    vote_history[0] <= kws_class_i;
                else
                    vote_history[0] <= 2'd2;  // Treat low-confidence as "other"

                // Generate filtered turn request using K-of-N voting
                if (voice_mode_en && !cooldown_active) begin
                    if (left_votes >= VOTE_K && kws_class_i == 2'd0 && kws_conf_i >= CONF_THRESH) begin
                        // Left turn — voted and current agrees
                        voice_turn_req   <= 2'b01;
                        voice_turn_valid <= 1'b1;
                        cooldown_cnt     <= COOLDOWN_TICKS;
                        last_cmd         <= 2'b01;
                        last_cmd_conf    <= kws_conf_i;
                        // Clear history after accepted turn
                        for (vi = 0; vi < VOTE_N; vi = vi + 1)
                            vote_history[vi] <= 2'd2;
                    end else if (right_votes >= VOTE_K && kws_class_i == 2'd1 && kws_conf_i >= CONF_THRESH) begin
                        // Right turn — voted and current agrees
                        voice_turn_req   <= 2'b10;
                        voice_turn_valid <= 1'b1;
                        cooldown_cnt     <= COOLDOWN_TICKS;
                        last_cmd         <= 2'b10;
                        last_cmd_conf    <= kws_conf_i;
                        // Clear history after accepted turn
                        for (vi = 0; vi < VOTE_N; vi = vi + 1)
                            vote_history[vi] <= 2'd2;
                    end
                end
            end
        end
    end

endmodule
