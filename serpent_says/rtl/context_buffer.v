// ============================================================================
// 16-Frame Context Buffer
// ============================================================================
// Maintains a rolling buffer of the last 16 mel frames (each 16 values).
// When a new frame arrives, it shifts the oldest frame out.
// Once 16 frames are collected, the flattened 256-element feature vector
// is available for MLP inference.
//
// Memory layout: frame[0..15][mel_bin 0..15] stored in a 256-entry BRAM.
//   Storage address = frame_idx * 16 + mel_bin
//   Read address (feat_addr) uses mel-major order to match Python:
//     feat_addr[7:4] = mel_bin, feat_addr[3:0] = frame (oldest=0, newest=15)
// ============================================================================

module context_buffer #(
    parameter N_MELS    = 16,
    parameter N_FRAMES  = 16,
    parameter FEAT_DIM  = 256  // N_MELS * N_FRAMES
)(
    input  wire        clk,
    input  wire        rst_n,
    // Input: new mel frame (written one value at a time)
    input  wire signed [15:0] mel_in,  // Raw log-mel (16-bit, pre-normalization)
    input  wire [3:0]  mel_idx,        // 0..15 within the frame
    input  wire        mel_we,
    input  wire        frame_done,     // Pulse: all 16 mel values written for this frame
    // Output: flattened feature vector
    output wire signed [15:0] feat_out, // Raw 16-bit for downstream normalization
    input  wire [7:0]  feat_addr,      // 0..255
    output reg         feat_ready      // High when ≥16 frames have been collected
);

    // ── Feature buffer (256 entries × 16 bits) ──
    reg signed [15:0] buf_mem [0:FEAT_DIM-1];

    // Track which slot receives the next frame (circular, 0..15)
    reg [3:0] write_frame_idx;
    reg [4:0] frame_count;         // Saturates at 16

    // ── Read port: map feature address through circular offset ──
    // Python flattens as mel-major: feature[k] = mel_bin[k/16], frame[k%16]
    // So feat_addr upper 4 bits = mel_bin, lower 4 bits = frame index.
    // Physical storage is frame*16+mel, so we swap the nibbles:
    //   phys_addr = (write_frame_idx + frame) * 16 + mel_bin
    wire [3:0] out_mel = feat_addr[7:4];   // mel bin  (outer dimension in Python)
    wire [3:0] out_frm = feat_addr[3:0];   // frame    (inner dimension in Python)
    wire [7:0] phys_addr = {(write_frame_idx + out_frm), out_mel};
    assign feat_out = buf_mem[phys_addr];

    // ── Write port: new mel values go into write_frame_idx slot ──
    wire [7:0] write_addr = {write_frame_idx, mel_idx};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_frame_idx <= 4'd0;
            frame_count     <= 5'd0;
            feat_ready      <= 1'b0;
        end else begin
            // Write incoming mel values
            if (mel_we) begin
                buf_mem[write_addr] <= mel_in;
            end

            // Advance to next frame slot when frame is complete
            if (frame_done) begin
                write_frame_idx <= write_frame_idx + 1; // wraps at 16

                if (frame_count < N_FRAMES) begin
                    frame_count <= frame_count + 1;
                end

                if (frame_count >= N_FRAMES - 1) begin
                    feat_ready <= 1'b1;
                end
            end
        end
    end

endmodule
