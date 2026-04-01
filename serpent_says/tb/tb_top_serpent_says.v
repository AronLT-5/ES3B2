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
        .GAME_TICK_COUNT_MAX(100),
        .INITIAL_LIVES(2)
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
    wire [7:0] score      = dut.score;
    wire [1:0] lives      = dut.lives;
    wire       would_hit_body     = dut.would_hit_body;
    wire       would_hit_body_raw = dut.would_hit_body_raw;
    wire       next_head_is_tail  = dut.next_head_is_tail;
    wire       any_collision      = dut.any_collision;
    wire [5:0] tail_x    = dut.tail_x;
    wire [5:0] tail_y    = dut.tail_y;

    integer err_count;

    // --- Helper tasks ---

    task wait_ticks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge dut.game_tick);
                @(negedge dut.game_tick);
            end
        end
    endtask

    task pulse_btnr;
        begin BTNR = 1'b1; #200; BTNR = 1'b0; end
    endtask

    task pulse_btnl;
        begin BTNL = 1'b1; #200; BTNL = 1'b0; end
    endtask

    initial begin
        CLK100MHZ  = 1'b0;
        CPU_RESETN = 1'b0;
        BTNL       = 1'b0;
        BTNR       = 1'b0;
        err_count  = 0;

        // ==========================================================
        // Scenario T: Tail-vacate safety (ticks 1-4)
        //
        // From reset: head=(5,5), dir=right, snake_len=4, lives=2
        // 3 consecutive right turns to U-turn:
        //   tick 1: right -> head=(6,5)  body=(5,5),(4,5),(3,5)
        //   tick 2: down  -> head=(6,6)  body=(6,5),(5,5),(4,5)
        //   tick 3: left  -> head=(5,6)  body=(6,6),(6,5),(5,5)
        //   tick 4: up    -> head=(5,5)  <- tail's old tile, safe
        // ==========================================================

        #100;
        CPU_RESETN = 1'b1;

        wait_ticks(1);   // tick 1: right -> head=(6,5)
        pulse_btnr();    // queue right->down

        wait_ticks(1);   // tick 2: down -> head=(6,6)
        pulse_btnr();    // queue down->left

        wait_ticks(1);   // tick 3: left -> head=(5,6)
        pulse_btnr();    // queue left->up

        // === Checkpoint T: pre-tick-4 wire check ===
        // Direction has been latched to up, next_head will be (5,5)
        // body2=(5,5) is the tail at snake_len=4
        // Combinational wires should show tail-vacate suppression

        if (dut.would_hit_body_raw !== 1'b1) begin
            $display("FAIL [T1]: would_hit_body_raw=%0b, expected 1", dut.would_hit_body_raw);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T1]: would_hit_body_raw=1 (raw match detected)");
        end

        if (dut.next_head_is_tail !== 1'b1) begin
            $display("FAIL [T2]: next_head_is_tail=%0b, expected 1", dut.next_head_is_tail);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T2]: next_head_is_tail=1 (tail lookup correct)");
        end

        if (dut.would_hit_body !== 1'b0) begin
            $display("FAIL [T3]: would_hit_body=%0b, expected 0 (tail-vacate)", dut.would_hit_body);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T3]: would_hit_body=0 (tail-vacate suppression works)");
        end

        if (dut.any_collision !== 1'b0) begin
            $display("FAIL [T4]: any_collision=%0b, expected 0", dut.any_collision);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T4]: any_collision=0 (no collision will fire)");
        end

        wait_ticks(1);   // tick 4: up -> head=(5,5), move accepted

        // === Checkpoint T2: post-tick-4 ===
        if (dut.head_x !== 6'd5 || dut.head_y !== 6'd5) begin
            $display("FAIL [T5]: head=(%0d,%0d), expected (5,5)", dut.head_x, dut.head_y);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T5]: head=(5,5) (moved to tail's old position)");
        end

        if (dut.game_over !== 1'b0) begin
            $display("FAIL [T6]: game_over=%0b, expected 0", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T6]: game_over=0");
        end

        if (dut.lives !== 2'd2) begin
            $display("FAIL [T7]: lives=%0d, expected 2", dut.lives);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T7]: lives=2 (no life lost)");
        end

        if (dut.score !== 8'd0) begin
            $display("FAIL [T8]: score=%0d, expected 0", dut.score);
            err_count = err_count + 1;
        end else begin
            $display("PASS [T8]: score=0 (unchanged)");
        end

        // ==========================================================
        // Hard reset between scenarios
        // ==========================================================
        CPU_RESETN = 1'b0; #100; CPU_RESETN = 1'b1;

        // ==========================================================
        // Scenario A: Food collection + score (ticks 1-12)
        //
        // Fresh reset: head=(5,5), dir=right, food=(12,10),
        // snake_len=4, lives=2, score=0
        //
        // Phase 1: 7 ticks right -> head at (12,5)
        // Phase 2: turn right->down, 5 ticks -> head at (12,10)=food
        // ==========================================================

        wait_ticks(7);   // 7 ticks right -> head at (12,5)

        // === Checkpoint A1: pre-eat baseline ===
        if (dut.snake_len !== 4'd4) begin
            $display("FAIL [A1]: snake_len=%0d, expected 4", dut.snake_len);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A1]: snake_len=4 (pre-eat)");
        end

        if (dut.score !== 8'd0) begin
            $display("FAIL [A2]: score=%0d, expected 0", dut.score);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A2]: score=0 (pre-eat)");
        end

        if (dut.lives !== 2'd2) begin
            $display("FAIL [A3]: lives=%0d, expected 2", dut.lives);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A3]: lives=2 (pre-eat)");
        end

        if (dut.game_over !== 1'b0) begin
            $display("FAIL [A4]: game_over=%0b, expected 0", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A4]: game_over=0 (pre-eat)");
        end

        pulse_btnr();    // queue right->down
        wait_ticks(5);   // 5 ticks down -> head at (12,10) = food

        // === Checkpoint A5: post-eat ===
        if (dut.snake_len !== 4'd5) begin
            $display("FAIL [A5]: snake_len=%0d, expected 5", dut.snake_len);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A5]: snake_len=5 (post-eat)");
        end

        if (dut.score !== 8'd1) begin
            $display("FAIL [A6]: score=%0d, expected 1", dut.score);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A6]: score=1 (post-eat)");
        end

        if (dut.lives !== 2'd2) begin
            $display("FAIL [A7]: lives=%0d, expected 2", dut.lives);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A7]: lives=2 (post-eat)");
        end

        if (dut.game_over !== 1'b0) begin
            $display("FAIL [A8]: game_over=%0b, expected 0", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A8]: game_over=0 (post-eat)");
        end

        if (dut.food_x !== 6'd25 || dut.food_y !== 6'd5) begin
            $display("FAIL [A9]: food=(%0d,%0d), expected (25,5)", dut.food_x, dut.food_y);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A9]: food relocated to (25,5)");
        end

        if (dut.body3_x !== 6'd12 || dut.body3_y !== 6'd6) begin
            $display("FAIL [A10]: body3=(%0d,%0d), expected (12,6)", dut.body3_x, dut.body3_y);
            err_count = err_count + 1;
        end else begin
            $display("PASS [A10]: body3=(12,6) (correct trailing tile)");
        end

        // ==========================================================
        // Scenario B: Self-collision, non-final death (ticks 13-17)
        //
        // Continue from A: snake_len=5, facing down, head=(12,10),
        // lives=2, score=1
        //
        //   tick 13: down  -> head=(12,11)
        //   tick 14: down  -> head=(12,12)
        //   tick 15: left  -> head=(11,12)
        //   tick 16: up    -> head=(11,11)
        //   tick 17: right -> next_head=(12,11) -> body2 SELF-COLLISION
        //
        // body2=(12,11) is NOT the tail (tail=body3=(12,10))
        // ==========================================================

        wait_ticks(2);   // ticks 13-14: down -> head at (12,12)
        pulse_btnr();    // queue down->left

        wait_ticks(1);   // tick 15: left -> head at (11,12)
        pulse_btnr();    // queue left->up

        wait_ticks(1);   // tick 16: up -> head at (11,11)
        pulse_btnr();    // queue up->right

        wait_ticks(1);   // tick 17: right -> self-collision -> respawn

        // === Checkpoint B: post-respawn ===
        if (dut.lives !== 2'd1) begin
            $display("FAIL [B1]: lives=%0d, expected 1", dut.lives);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B1]: lives=1 (decremented from 2)");
        end

        if (dut.game_over !== 1'b0) begin
            $display("FAIL [B2]: game_over=%0b, expected 0", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B2]: game_over=0 (non-final death)");
        end

        if (dut.score !== 8'd1) begin
            $display("FAIL [B3]: score=%0d, expected 1", dut.score);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B3]: score=1 (preserved across respawn)");
        end

        if (dut.head_x !== 6'd5 || dut.head_y !== 6'd5) begin
            $display("FAIL [B4]: head=(%0d,%0d), expected (5,5)", dut.head_x, dut.head_y);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B4]: head=(5,5) (respawned to init)");
        end

        if (dut.direction !== 2'b01) begin
            $display("FAIL [B5]: direction=%0b, expected 01", dut.direction);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B5]: direction=01 (respawned to right)");
        end

        if (dut.snake_len !== 4'd4) begin
            $display("FAIL [B6]: snake_len=%0d, expected 4", dut.snake_len);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B6]: snake_len=4 (respawned to init)");
        end

        if (dut.food_x !== 6'd12 || dut.food_y !== 6'd10) begin
            $display("FAIL [B7]: food=(%0d,%0d), expected (12,10)", dut.food_x, dut.food_y);
            err_count = err_count + 1;
        end else begin
            $display("PASS [B7]: food=(12,10) (reset to FOOD_CAND0)");
        end

        // ==========================================================
        // Scenario C: Wall collision, final death (ticks 18-23)
        //
        // Continue from respawn: head=(5,5), dir=right, lives=1,
        // score=1
        //
        // Turn left (right->up), then 5 ticks up to reach (5,0),
        // then 1 more tick -> would_hit_wall -> FINAL DEATH
        // ==========================================================

        pulse_btnl();    // queue right->up
        wait_ticks(5);   // ticks 18-22: up -> head at (5,0)

        wait_ticks(1);   // tick 23: would_hit_wall -> final death

        // === Checkpoint C ===
        if (dut.lives !== 2'd0) begin
            $display("FAIL [C1]: lives=%0d, expected 0", dut.lives);
            err_count = err_count + 1;
        end else begin
            $display("PASS [C1]: lives=0 (final death)");
        end

        if (dut.game_over !== 1'b1) begin
            $display("FAIL [C2]: game_over=%0b, expected 1", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [C2]: game_over=1 (game frozen)");
        end

        if (dut.score !== 8'd1) begin
            $display("FAIL [C3]: score=%0d, expected 1", dut.score);
            err_count = err_count + 1;
        end else begin
            $display("PASS [C3]: score=1 (preserved through final death)");
        end

        // Verify freeze: wait 2 ticks worth of time, state should not change
        #8000;

        if (dut.game_over !== 1'b1) begin
            $display("FAIL [C4]: game_over=%0b after freeze, expected 1", dut.game_over);
            err_count = err_count + 1;
        end else begin
            $display("PASS [C4]: game_over=1 (still frozen after delay)");
        end

        if (dut.lives !== 2'd0) begin
            $display("FAIL [C5]: lives=%0d after freeze, expected 0", dut.lives);
            err_count = err_count + 1;
        end else begin
            $display("PASS [C5]: lives=0 (still frozen after delay)");
        end

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
