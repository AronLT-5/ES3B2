`timescale 1ns / 1ps

module tb_top_serpent_says;

    reg CLK100MHZ;
    reg CPU_RESETN;
    reg BTNL;
    reg BTNR;

    wire VGA_HS;
    wire VGA_VS;
    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;

    top_serpent_says #(
        .GAME_TICK_COUNT_MAX(100)  // 100 clk_25mhz cycles = 4 us per tick
    ) dut (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .BTNL(BTNL),
        .BTNR(BTNR),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B)
    );

    always #5 CLK100MHZ = ~CLK100MHZ;

    initial begin
        CLK100MHZ  = 1'b0;
        CPU_RESETN = 1'b0;
        BTNL       = 1'b0;
        BTNR       = 1'b0;

        // ==========================================================
        // Scenario: Food collection
        // Start: head=(5,5), dir=right, food at (12,10)
        //
        // Phase 1: Move right 7 ticks to reach x=12
        //   tick 1: (6,5)   tick 2: (7,5)   tick 3: (8,5)
        //   tick 4: (9,5)   tick 5: (10,5)  tick 6: (11,5)
        //   tick 7: (12,5)
        //
        // Phase 2: Turn right (right->down), move down 5 ticks to y=10
        //   tick 8: (12,6)  tick 9: (12,7)  tick 10: (12,8)
        //   tick 11: (12,9) tick 12: (12,10) <- food! ate_food fires
        //
        // Expected on tick 12:
        //   head moves to (12,10)
        //   food_x/food_y change from (12,10) to (25,5)
        //   game_over stays 0
        //
        // Phase 3: Observe a few more ticks to confirm continued play
        // ==========================================================

        // Reset
        #100;
        CPU_RESETN = 1'b1;

        // Phase 1: wait 7 ticks (head reaches (12,5))
        #29000;

        // Turn right: right(01) -> down(10)
        BTNR = 1'b1; #200; BTNR = 1'b0;

        // Phase 2: wait 5 ticks (head reaches food at (12,10))
        #21000;

        // Phase 3: observe 4 more ticks post-collection
        #16000;

        $finish;
    end

endmodule
