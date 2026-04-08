// ============================================================================
// CIC Decimation Filter (4th Order)
// ============================================================================
// Converts 1-bit PDM bitstream to multi-bit PCM at a lower sample rate.
//
// Structure: 4 integrators → decimate by R → 4 comb filters
// Bit growth = ORDER * log2(R*M) where M=1 (differential delay).
// For R=156, growth ≈ 29 bits. Using 32-bit accumulators for headroom.
//
// PDM at 2.5 MHz, R=156 → PCM at ~16025 Hz (close enough to 16 kHz).
// ============================================================================

module cic_decimator #(
    parameter ORDER    = 4,      // Filter order
    parameter DECIM_R  = 156,    // Decimation ratio
    parameter OUT_BITS = 16      // Output PCM width
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    pdm_bit,     // 1-bit PDM input (+1 or -1)
    input  wire                    pdm_valid,   // PDM sample valid strobe
    output reg  signed [OUT_BITS-1:0] pcm_out,  // Decimated PCM output
    output reg                     pcm_valid    // PCM output valid strobe
);

    // Internal accumulator width (must accommodate bit growth)
    localparam ACC_W = 32;

    // Integrator stages (run at PDM rate)
    reg signed [ACC_W-1:0] integ [0:ORDER-1];

    // Comb stages (run at decimated rate)
    reg signed [ACC_W-1:0] comb_delay [0:ORDER-1];
    reg signed [ACC_W-1:0] comb_out   [0:ORDER-1];

    // Decimation counter
    reg [$clog2(DECIM_R)-1:0] decim_cnt;

    // Convert PDM bit to signed: 0 → -1, 1 → +1
    wire signed [ACC_W-1:0] pdm_signed = pdm_bit ? 32'sd1 : -32'sd1;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ORDER; i = i + 1) begin
                integ[i]      <= 0;
                comb_delay[i] <= 0;
                comb_out[i]   <= 0;
            end
            decim_cnt <= 0;
            pcm_out   <= 0;
            pcm_valid <= 1'b0;
        end else begin
            pcm_valid <= 1'b0;

            if (pdm_valid) begin
                // Integrator chain (accumulate at PDM rate)
                integ[0] <= integ[0] + pdm_signed;
                for (i = 1; i < ORDER; i = i + 1) begin
                    integ[i] <= integ[i] + integ[i-1];
                end

                // Decimation counter
                if (decim_cnt == DECIM_R - 1) begin
                    decim_cnt <= 0;

                    // Comb chain (process at decimated rate)
                    // Stage 0: input from last integrator
                    comb_out[0]   <= integ[ORDER-1] - comb_delay[0];
                    comb_delay[0] <= integ[ORDER-1];

                    for (i = 1; i < ORDER; i = i + 1) begin
                        comb_out[i]   <= comb_out[i-1] - comb_delay[i];
                        comb_delay[i] <= comb_out[i-1];
                    end

                    // Output: extract top bits with rounding
                    // Bit growth = ORDER * ceil(log2(R)) ≈ 29
                    // Shift right by (ACC_W - OUT_BITS) = 16 bits
                    pcm_out   <= comb_out[ORDER-1][ACC_W-1 -: OUT_BITS];
                    pcm_valid <= 1'b1;
                end else begin
                    decim_cnt <= decim_cnt + 1;
                end
            end
        end
    end

endmodule
