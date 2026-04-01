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

    // Waveform-friendly aliases for key internal signals
    wire [5:0] head_x    = dut.head_x;
    wire [5:0] head_y    = dut.head_y;
    wire [5:0] body0_x   = dut.body0_x;
    wire [5:0] body0_y   = dut.body0_y;
    wire [5:0] body1_x   = dut.body1_x;
    wire [5:0] body1_y   = dut.body1_y;
    wire [5:0] body2_x   = dut.body2_x;
    wire [5:0] body2_y   = dut.body2_y;
    wire [5:0] body3_x   = dut.body3_x;
    wire [5:0] body3_y   = dut.body3_y;
    wire [3:0] snake_len  = dut.snake_len;
    wire [5:0] food_x    = dut.food_x;
    wire [5:0] food_y    = dut.food_y;
    wire       ate_food   = dut.ate_food;
    wire       game_tick  = dut.game_tick;
    wire [1:0] direction  = dut.direction;
    wire       game_over  = dut.game_over;

    integer err_count;

    initial begin
        CLK100MHZ  = 1'b0;
        CPU_RESETN = 1'b0;
        BTNL       = 1'b0;
        BTNR       = 1'b0;
        err_count  = 0;

        // ==========================================================
        // Scenario: Food collection + snake growth
        // Start: head=(5,5), dir=right, food at (12,10), snake_len=4
        //
        // Phase 1: Move right 7 ticks to reach x=12
        //   tick 1: (6,5)   tick 2: (7,5)   tick 3: (8,5)
        //   tick 4: (9,5)   tick 5: (10,5)  tick 6: (11,5)
        //   tick 7: (12,5)
        //
        // Phase 2: Turn right (right->down), move down 5 ticks to y=10
        //   tick 8:  (12,6)  tick 9:  (12,7)  tick 10: (12,8)
        //   tick 11: (12,9)  tick 12: (12,10) <- food! ate_food fires
        //
        // Expected on tick 12:
        //   head moves to (12,10)
        //   snake_len changes from 4 to 5
        //   body3 becomes (12,6) (newly visible tail)
        //   food relocates to (25,5) (next safe candidate)
        //   game_over stays 0
        //
        // Phase 3: Observe a few more ticks to confirm continued play
        // ==========================================================

        // Reset
        #100;
        CPU_RESETN = 1'b1;

        // Phase 1: wait 7 ticks (head reaches (12,5))
        #29000;

        // === Checkpoint A: pre-eat baseline ===
        if (dut.snake_len !== 4'd4) begin
            $display("FAIL [A1]: snake_len=%0d, expected 4", dut.snake_len);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A1]: snake_len=%0d (pre-eat)", dut.snake_len);
        end

        if (dut.game_over !== 1'b0) begin
            $display("FAIL [A2]: game_over=%0b, expected 0", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A2]: game_over=0 (pre-eat)");
        end

        // Turn right: right(01) -> down(10)
        BTNR = 1'b1; #200; BTNR = 1'b0;

        // Phase 2: wait 5 ticks (head reaches food at (12,10))
        #21000;

        // === Checkpoint B: post-eat growth ===
        if (dut.snake_len !== 4'd5) begin
            $display("FAIL [B1]: snake_len=%0d, expected 5", dut.snake_len);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B1]: snake_len=%0d (post-eat)", dut.snake_len);
        end

        if (dut.game_over !== 1'b0) begin
            $display("FAIL [B2]: game_over=%0b, expected 0", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B2]: game_over=0 (post-eat)");
        end

        if (dut.food_x !== 6'd25 || dut.food_y !== 6'd5) begin
            $display("FAIL [B3]: food=(%0d,%0d), expected (25,5)", dut.food_x, dut.food_y);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B3]: food relocated to (%0d,%0d)", dut.food_x, dut.food_y);
        end

        if (dut.body3_x !== 6'd12 || dut.body3_y !== 6'd6) begin
            $display("FAIL [B4]: body3=(%0d,%0d), expected (12,6)", dut.body3_x, dut.body3_y);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B4]: body3=(%0d,%0d) (correct trailing tile)", dut.body3_x, dut.body3_y);
        end

        // Phase 3: observe 4 more ticks post-collection
        #16000;

        // === Summary ===
        if (err_count == 0) begin
            $display("ALL CHECKS PASSED");
        end else begin
            $display("FAILED: %0d check(s) failed", err_count);
            $stop;
        end

        $finish;
    end

endmodule
