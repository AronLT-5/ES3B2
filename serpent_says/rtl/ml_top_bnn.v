// ============================================================================
// ML Top (BNN variant) — Full Audio-to-Classification Pipeline
// ============================================================================
// Same pipeline as ml_top.v but uses BNN inference instead of int8 MLP:
//
//   PDM mic -> CIC -> frame buffer -> feature pipeline -> context buffer
//   -> normalizer (256 int8 features) -> BNN inference -> command filter
//   -> voice_turn_req
//
// BNN inference replaces the int8 MLP with:
//   Layer 1: 256 int8 x binary weights -> 128 binary outputs (sign)
//   Layer 2: 128 binary x binary weights -> 3 logits (argmax)
//
// Benefits over int8 MLP:
//   - 0 DSP blocks (was 0 in int8 version too, but BNN is simpler logic)
//   - ~2 KB weight storage vs ~8.4 KB (binary packing)
//   - Wider hidden layer (128 vs 32) compensates for binarization loss
//
// All other modules (PDM, CIC, FFT, mel, normalizer, command_filter)
// are identical to ml_top.v.
// ============================================================================

module ml_top_bnn #(
    parameter CLK_FREQ       = 25_000_000,
    parameter PDM_CLK_DIV    = 10,
    parameter CIC_DECIM      = 156,
    parameter CONF_THRESH    = 8'sd2,
    parameter COOLDOWN_TICKS = 24'd12_500_000  // 500ms at 25 MHz
)(
    input  wire        clk,
    input  wire        rst_n,
    // Microphone
    input  wire        pdm_data_i,
    output wire        pdm_clk_o,
    // Game control
    input  wire        voice_mode_en,
    // Turn request output
    output wire [1:0]  voice_turn_req,
    output wire        voice_turn_valid,
    // Raw KWS output (for info bar)
    output wire [1:0]  voice_kws_class,
    output wire [7:0]  voice_kws_conf,
    output wire        voice_kws_valid,
    // Debug
    output wire [1:0]  last_cmd,
    output wire [7:0]  last_cmd_conf,
    output wire        ml_alive
);

    // ════════════════════════════════════════════════════════════
    // 1. PDM Capture (unchanged)
    // ════════════════════════════════════════════════════════════
    wire pdm_bit, pdm_valid;

    pdm_capture #(.CLK_DIV(PDM_CLK_DIV)) u_pdm (
        .clk        (clk),
        .rst_n      (rst_n),
        .pdm_data_i (pdm_data_i),
        .pdm_clk_o  (pdm_clk_o),
        .pdm_bit_o  (pdm_bit),
        .pdm_valid_o(pdm_valid)
    );

    // ════════════════════════════════════════════════════════════
    // 2. CIC Decimator (unchanged)
    // ════════════════════════════════════════════════════════════
    wire signed [15:0] pcm_sample;
    wire               pcm_valid;

    cic_decimator #(
        .ORDER   (4),
        .DECIM_R (CIC_DECIM),
        .OUT_BITS(16)
    ) u_cic (
        .clk       (clk),
        .rst_n     (rst_n),
        .pdm_bit   (pdm_bit),
        .pdm_valid (pdm_valid),
        .pcm_out   (pcm_sample),
        .pcm_valid (pcm_valid)
    );

    // ════════════════════════════════════════════════════════════
    // 3. Frame Buffer (unchanged)
    // ════════════════════════════════════════════════════════════
    wire [7:0]  fb_addr;
    wire signed [15:0] fb_data;
    wire        fb_ready;
    wire        fb_consumed;

    frame_buffer #(
        .FRAME_LEN   (256),
        .HOP_LEN     (128),
        .SAMPLE_WIDTH(16)
    ) u_frame_buf (
        .clk           (clk),
        .rst_n         (rst_n),
        .sample_in     (pcm_sample),
        .sample_valid  (pcm_valid),
        .frame_data    (fb_data),
        .frame_addr    (fb_addr),
        .frame_ready   (fb_ready),
        .frame_consumed(fb_consumed)
    );

    // ════════════════════════════════════════════════════════════
    // 4. Feature Pipeline (unchanged)
    // ════════════════════════════════════════════════════════════
    wire signed [15:0] ctx_mel_in;
    wire [3:0]         ctx_mel_idx;
    wire               ctx_mel_we;
    wire               ctx_frame_done;
    wire               feat_busy;

    feature_pipeline u_feat (
        .clk           (clk),
        .rst_n         (rst_n),
        .fb_addr       (fb_addr),
        .fb_data       (fb_data),
        .fb_ready      (fb_ready),
        .fb_consumed   (fb_consumed),
        .ctx_mel_in    (ctx_mel_in),
        .ctx_mel_idx   (ctx_mel_idx),
        .ctx_mel_we    (ctx_mel_we),
        .ctx_frame_done(ctx_frame_done),
        .busy          (feat_busy)
    );

    // ════════════════════════════════════════════════════════════
    // 5. Context Buffer (unchanged)
    // ════════════════════════════════════════════════════════════
    wire signed [15:0] ctx_feat_out;
    wire [7:0]         ctx_feat_addr;
    wire               ctx_feat_ready;

    context_buffer u_ctx (
        .clk        (clk),
        .rst_n      (rst_n),
        .mel_in     (ctx_mel_in),
        .mel_idx    (ctx_mel_idx),
        .mel_we     (ctx_mel_we),
        .frame_done (ctx_frame_done),
        .feat_out   (ctx_feat_out),
        .feat_addr  (ctx_feat_addr),
        .feat_ready (ctx_feat_ready)
    );

    // ════════════════════════════════════════════════════════════
    // 6. Normalizer (unchanged — outputs 256 x int8)
    // ════════════════════════════════════════════════════════════
    wire [7:0]        norm_feat_addr;
    wire signed [7:0] norm_int8_out;
    wire [7:0]        norm_int8_addr;
    wire              norm_int8_we;
    wire              norm_busy, norm_done;
    reg               norm_start;

    assign ctx_feat_addr = norm_feat_addr;

    normalizer u_norm (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (norm_start),
        .busy         (norm_busy),
        .done         (norm_done),
        .feature_in   (ctx_feat_out),
        .feature_addr (norm_feat_addr),
        .int8_out     (norm_int8_out),
        .int8_addr    (norm_int8_addr),
        .int8_we      (norm_int8_we)
    );

    // ── Normalized feature buffer (256 x int8) ──
    reg signed [7:0] norm_feat_buf [0:255];
    always @(posedge clk) begin
        if (norm_int8_we)
            norm_feat_buf[norm_int8_addr] <= norm_int8_out;
    end

    // ════════════════════════════════════════════════════════════
    // 7. BNN Inference (256 int8 -> 128 binary -> 3 logits)
    //    *** This is the only change from ml_top.v ***
    // ════════════════════════════════════════════════════════════
    wire [7:0]        inf_feat_addr;
    wire signed [7:0] inf_feat_data;
    wire [1:0]        inf_class;
    wire signed [7:0] inf_conf;
    wire              inf_valid;
    wire              inf_busy, inf_done;
    reg               inf_start;

    assign inf_feat_data = norm_feat_buf[inf_feat_addr];

    bnn_inference u_bnn (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (inf_start),
        .busy      (inf_busy),
        .done      (inf_done),
        .feat_addr (inf_feat_addr),
        .feat_data (inf_feat_data),
        .kws_class (inf_class),
        .kws_conf  (inf_conf),
        .kws_valid (inf_valid)
    );

    // ════════════════════════════════════════════════════════════
    // 8. Command Filter (unchanged)
    // ════════════════════════════════════════════════════════════
    command_filter #(
        .CONF_THRESH   (CONF_THRESH),
        .COOLDOWN_TICKS(COOLDOWN_TICKS)
    ) u_cmd_filt (
        .clk            (clk),
        .rst_n          (rst_n),
        .voice_mode_en  (voice_mode_en),
        .kws_class_i    (inf_class),
        .kws_conf_i     (inf_conf),
        .kws_valid_i    (inf_valid),
        .voice_kws_class(voice_kws_class),
        .voice_kws_conf (voice_kws_conf),
        .voice_kws_valid(voice_kws_valid),
        .voice_turn_req (voice_turn_req),
        .voice_turn_valid(voice_turn_valid),
        .last_cmd       (last_cmd),
        .last_cmd_conf  (last_cmd_conf),
        .ml_alive       (ml_alive)
    );

    // ════════════════════════════════════════════════════════════
    // 9. Sequencing: context_ready -> normalize -> infer (unchanged)
    // ════════════════════════════════════════════════════════════
    localparam ML_IDLE  = 2'd0;
    localparam ML_NORM  = 2'd1;
    localparam ML_INFER = 2'd2;

    reg [1:0] ml_state;

    reg ctx_frame_done_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ctx_frame_done_d <= 1'b0;
        else        ctx_frame_done_d <= ctx_frame_done;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ml_state   <= ML_IDLE;
            norm_start <= 1'b0;
            inf_start  <= 1'b0;
        end else begin
            norm_start <= 1'b0;
            inf_start  <= 1'b0;

            case (ml_state)
                ML_IDLE: begin
                    if (ctx_feat_ready && ctx_frame_done_d && !norm_busy && !inf_busy) begin
                        ml_state   <= ML_NORM;
                        norm_start <= 1'b1;
                    end
                end

                ML_NORM: begin
                    if (norm_done) begin
                        ml_state  <= ML_INFER;
                        inf_start <= 1'b1;
                    end
                end

                ML_INFER: begin
                    if (inf_done) begin
                        ml_state <= ML_IDLE;
                    end
                end

                default: ml_state <= ML_IDLE;
            endcase
        end
    end

endmodule
