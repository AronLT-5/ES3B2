// ============================================================================
// Feature Extraction Pipeline Controller
// ============================================================================
// Orchestrates the feature extraction flow:
//   1. Wait for frame_buffer to signal a complete frame
//   2. Apply Hann window to each sample → load into FFT
//   3. Run 256-point FFT
//   4. Compute power spectrum + mel filterbank + log2
//   5. Write raw 16-bit log-mel values to context buffer
//
// Normalization is NOT done here — it happens after the context buffer
// assembles the full 256-element feature vector in ml_top.
//
// Requires: hann_window.mem (256 entries, signed hex16, Q1.15 format)
// ============================================================================

module feature_pipeline #(
    parameter FRAME_LEN = 256,
    parameter N_MELS    = 16,
    parameter HANN_FILE = "hann_window.mem"
)(
    input  wire        clk,
    input  wire        rst_n,
    // Frame buffer interface
    output reg  [7:0]  fb_addr,          // Read address for frame buffer
    input  wire signed [15:0] fb_data,   // Sample from frame buffer
    input  wire        fb_ready,         // Frame available
    output reg         fb_consumed,      // Pulse: done reading frame
    // Context buffer interface (raw 16-bit log-mel values)
    output reg  signed [15:0] ctx_mel_in,
    output reg  [3:0]  ctx_mel_idx,
    output reg         ctx_mel_we,
    output reg         ctx_frame_done,
    // Status
    output reg         busy
);

    // ── Hann window ROM (Q1.15 signed) ──
    reg signed [15:0] hann_rom [0:FRAME_LEN-1];
    initial $readmemh(HANN_FILE, hann_rom);

    // ── Sub-module signals ──

    // FFT
    reg         fft_start;
    wire        fft_busy, fft_done;
    reg  signed [15:0] fft_din;
    reg  [7:0]  fft_din_addr;
    reg         fft_din_we;
    wire signed [15:0] fft_dout_re, fft_dout_im;
    reg  [7:0]  fft_dout_addr;

    // Mel power
    reg         mel_start;
    wire        mel_busy, mel_done;
    wire [7:0]  mel_fft_addr;
    wire signed [15:0] mel_out;
    wire [3:0]  mel_read_addr;

    // ── FFT instance ──
    fft_256 u_fft (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (fft_start),
        .busy      (fft_busy),
        .done      (fft_done),
        .din_re    (fft_din),
        .din_addr  (fft_din_addr),
        .din_we    (fft_din_we),
        .dout_re   (fft_dout_re),
        .dout_im   (fft_dout_im),
        .dout_addr (fft_dout_addr)
    );

    // ── Mel power instance ──
    // Connect FFT read port through mux (mel module drives addr during processing)
    always @(*) begin
        if (mel_busy)
            fft_dout_addr = mel_fft_addr;
        else
            fft_dout_addr = 8'd0;
    end

    mel_power u_mel (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (mel_start),
        .busy     (mel_busy),
        .done     (mel_done),
        .fft_addr (mel_fft_addr),
        .fft_re   (fft_dout_re),
        .fft_im   (fft_dout_im),
        .mel_out  (mel_out),
        .mel_addr (mel_read_addr)
    );

    // ── Mel read address driven combinationally from output counter ──
    // mel_out = mel_log[mel_read_addr] is combinational in mel_power,
    // so it settles within the same cycle when mel_read_addr changes.
    assign mel_read_addr = out_idx;

    // ── Main FSM ──
    localparam P_IDLE     = 3'd0;
    localparam P_WINDOW   = 3'd1;  // Apply Hann window + load FFT
    localparam P_FFT      = 3'd2;  // Run FFT
    localparam P_MEL      = 3'd3;  // Power spectrum + mel + log
    localparam P_OUTPUT   = 3'd4;  // Write raw mel values to context buffer
    localparam P_DONE     = 3'd5;

    reg [2:0]  pipe_state;
    reg [8:0]  win_idx;         // Window sample counter
    reg [3:0]  out_idx;         // Output mel bin counter

    // Delayed fb_addr for correct Hann window alignment
    // When fb_addr=N was set last cycle, fb_data=sample[N] this cycle,
    // so hann_rom should use the same index N.
    reg [7:0] fb_addr_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            fb_addr_d <= 8'd0;
        else
            fb_addr_d <= fb_addr;
    end

    // Windowing: sample × hann coefficient (Q15.0 × Q1.15 → Q16.15, >>15 → Q16.0)
    wire signed [31:0] windowed_product = fb_data * hann_rom[fb_addr_d];
    wire signed [15:0] windowed_sample  = (windowed_product + 32'sd16384) >>> 15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pipe_state    <= P_IDLE;
            win_idx       <= 0;
            out_idx       <= 0;
            busy          <= 1'b0;
            fb_addr       <= 0;
            // fb_addr_d reset handled in its own always block
            fb_consumed   <= 1'b0;
            fft_start     <= 1'b0;
            fft_din       <= 0;
            fft_din_addr  <= 0;
            fft_din_we    <= 1'b0;
            mel_start     <= 1'b0;
            ctx_mel_in    <= 0;
            ctx_mel_idx   <= 0;
            ctx_mel_we    <= 1'b0;
            ctx_frame_done <= 1'b0;
        end else begin
            // Default pulse signals low
            fft_start      <= 1'b0;
            fft_din_we     <= 1'b0;
            mel_start      <= 1'b0;
            fb_consumed    <= 1'b0;
            ctx_mel_we     <= 1'b0;
            ctx_frame_done <= 1'b0;

            case (pipe_state)
                P_IDLE: begin
                    if (fb_ready) begin
                        pipe_state <= P_WINDOW;
                        win_idx    <= 0;
                        fb_addr    <= 0;
                        busy       <= 1'b1;
                    end
                end

                P_WINDOW: begin
                    // Read sample from frame buffer, multiply by Hann, write to FFT
                    // Pipeline: addr set → data available next cycle → multiply → write
                    if (win_idx < FRAME_LEN) begin
                        // Write windowed sample to FFT (1 cycle behind fb_addr)
                        if (win_idx > 0) begin
                            fft_din      <= windowed_sample;
                            fft_din_addr <= fb_addr_d;
                            fft_din_we   <= 1'b1;
                        end
                        fb_addr <= win_idx[7:0];
                        win_idx <= win_idx + 1;
                    end else begin
                        // Write last sample
                        fft_din      <= windowed_sample;
                        fft_din_addr <= fb_addr_d;
                        fft_din_we   <= 1'b1;

                        fb_consumed  <= 1'b1;
                        pipe_state   <= P_FFT;
                        fft_start    <= 1'b1;
                    end
                end

                P_FFT: begin
                    if (fft_done) begin
                        pipe_state <= P_MEL;
                        mel_start  <= 1'b1;
                    end
                end

                P_MEL: begin
                    if (mel_done) begin
                        pipe_state <= P_OUTPUT;
                        out_idx    <= 0;
                    end
                end

                P_OUTPUT: begin
                    // mel_read_addr = out_idx (combinational), mel_out valid now
                    ctx_mel_in    <= mel_out;
                    ctx_mel_idx   <= out_idx;
                    ctx_mel_we    <= 1'b1;

                    if (out_idx == N_MELS - 1) begin
                        pipe_state     <= P_DONE;
                        ctx_frame_done <= 1'b1;
                    end else begin
                        out_idx <= out_idx + 1;
                    end
                end

                P_DONE: begin
                    busy       <= 1'b0;
                    pipe_state <= P_IDLE;
                end

                default: pipe_state <= P_IDLE;
            endcase
        end
    end

endmodule
