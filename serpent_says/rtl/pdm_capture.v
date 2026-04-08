// ============================================================================
// PDM Microphone Capture
// ============================================================================
// Generates PDM clock for onboard MEMS microphone (Nexys 4DDR / Nexys A7)
// and captures the 1-bit PDM data stream on each rising edge.
//
// PDM clock is generated via a clock-enable toggle — no new clock domain.
// Default: 25 MHz system clock / 10 = 2.5 MHz PDM clock.
// ============================================================================

module pdm_capture #(
    parameter CLK_DIV = 10   // sys_clk / CLK_DIV = PDM clock frequency
)(
    input  wire clk,         // System clock (25 MHz)
    input  wire rst_n,       // Active-low reset
    input  wire pdm_data_i,  // PDM data from microphone pin
    output reg  pdm_clk_o,   // PDM clock to microphone pin
    output reg  pdm_bit_o,   // Captured PDM bit value
    output reg  pdm_valid_o  // Pulse: new PDM bit captured (rising edge of pdm_clk)
);

    // Clock divider counter
    localparam HALF_DIV = CLK_DIV / 2;
    reg [$clog2(CLK_DIV)-1:0] clk_cnt;

    // Synchronizer for PDM data (2-stage to avoid metastability)
    reg pdm_sync_1, pdm_sync_2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pdm_sync_1 <= 1'b0;
            pdm_sync_2 <= 1'b0;
        end else begin
            pdm_sync_1 <= pdm_data_i;
            pdm_sync_2 <= pdm_sync_1;
        end
    end

    // Generate PDM clock and capture data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt     <= 0;
            pdm_clk_o   <= 1'b0;
            pdm_bit_o   <= 1'b0;
            pdm_valid_o <= 1'b0;
        end else begin
            pdm_valid_o <= 1'b0;

            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end

            // Toggle PDM clock at half-period
            if (clk_cnt == HALF_DIV - 1) begin
                pdm_clk_o <= 1'b1;
                // Capture PDM data on rising edge
                pdm_bit_o   <= pdm_sync_2;
                pdm_valid_o <= 1'b1;
            end else if (clk_cnt == CLK_DIV - 1) begin
                pdm_clk_o <= 1'b0;
            end
        end
    end

endmodule
