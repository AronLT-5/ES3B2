// ============================================================================
// Frame Buffer with Hop
// ============================================================================
// Collects FRAME_LEN PCM samples, then signals frame_ready.
// Uses HOP_LEN overlap: after a frame is consumed, the buffer slides
// forward by HOP_LEN samples (keeping FRAME_LEN - HOP_LEN old samples).
//
// Double-buffered: ping-pong between two banks so collection continues
// while the previous frame is being processed.
//
// Default: 256-sample frames with 128-sample hop.
// ============================================================================

module frame_buffer #(
    parameter FRAME_LEN    = 256,
    parameter HOP_LEN      = 128,
    parameter SAMPLE_WIDTH = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,
    // Input: PCM samples
    input  wire signed [SAMPLE_WIDTH-1:0] sample_in,
    input  wire                       sample_valid,
    // Output: completed frame (read port)
    output wire signed [SAMPLE_WIDTH-1:0] frame_data,
    input  wire [7:0]                 frame_addr,   // 0..FRAME_LEN-1
    output reg                        frame_ready,  // Level: held high until frame_consumed
    input  wire                       frame_consumed // Acknowledge: releases the frame buffer
);

    // Two frame banks (ping-pong)
    reg signed [SAMPLE_WIDTH-1:0] bank0 [0:FRAME_LEN-1];
    reg signed [SAMPLE_WIDTH-1:0] bank1 [0:FRAME_LEN-1];

    reg        active_bank;     // Which bank is being filled (0 or 1)
    reg [8:0]  write_ptr;       // Write position within the active bank
    reg        first_frame;     // True until the first complete frame

    // The read bank is the opposite of the active bank
    wire read_bank = ~active_bank;
    assign frame_data = read_bank ? bank1[frame_addr] : bank0[frame_addr];

    // Copy overlap region when switching banks
    reg        copying;
    reg [8:0]  copy_idx;
    localparam OVERLAP = FRAME_LEN - HOP_LEN;  // 128

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_bank <= 1'b0;
            write_ptr   <= 0;
            first_frame <= 1'b1;
            frame_ready <= 1'b0;
            copying     <= 1'b0;
            copy_idx    <= 0;
        end else begin
            // Clear frame_ready when downstream signals consumed
            if (frame_consumed)
                frame_ready <= 1'b0;

            if (copying) begin
                // Copy overlap from read bank to active bank
                if (copy_idx < OVERLAP) begin
                    if (active_bank) begin
                        bank1[copy_idx] <= bank0[HOP_LEN + copy_idx[7:0]];
                    end else begin
                        bank0[copy_idx] <= bank1[HOP_LEN + copy_idx[7:0]];
                    end
                    copy_idx <= copy_idx + 1;
                end else begin
                    copying   <= 1'b0;
                    write_ptr <= OVERLAP;
                end
            end else if (sample_valid) begin
                // Write sample to active bank
                if (active_bank)
                    bank1[write_ptr[7:0]] <= sample_in;
                else
                    bank0[write_ptr[7:0]] <= sample_in;

                if (write_ptr == FRAME_LEN - 1) begin
                    // Frame complete — only switch if read bank is free
                    if (!frame_ready) begin
                        first_frame <= 1'b0;
                        frame_ready <= 1'b1;
                        // Switch banks and start copying overlap
                        active_bank <= ~active_bank;
                        copying     <= 1'b1;
                        copy_idx    <= 0;
                    end
                    // If frame_ready still high (previous frame not consumed),
                    // stall: hold write_ptr, drop this sample. The hop will
                    // re-synchronize once downstream catches up.
                end else begin
                    write_ptr <= write_ptr + 1;
                end
            end
        end
    end

endmodule
