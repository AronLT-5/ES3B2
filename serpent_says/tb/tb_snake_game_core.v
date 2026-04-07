`timescale 1ns / 1ps

module tb_snake_game_core;

    reg        clk, reset_n;
    reg        game_tick, start_btn, pause_sw;
    reg  [1:0] player_turn_req;
    reg        player_turn_valid;
    reg  [1:0] turn_source_in;

    wire [2:0]  fsm_state;
    wire [5:0]  p_head_x, p_head_y;
    wire [5:0]  p_body0_x, p_body0_y, p_body1_x, p_body1_y;
    wire [5:0]  p_body2_x, p_body2_y, p_body3_x, p_body3_y;
    wire [5:0]  p_body4_x, p_body4_y, p_body5_x, p_body5_y;
    wire [5:0]  p_body6_x, p_body6_y;
    wire [1:0]  p_direction;
    wire [3:0]  p_length;
    wire [1:0]  p_lives;
    wire [5:0]  r_head_x, r_head_y;
    wire [5:0]  r_body0_x, r_body0_y, r_body1_x, r_body1_y;
    wire [5:0]  r_body2_x, r_body2_y, r_body3_x, r_body3_y;
    wire [5:0]  r_body4_x, r_body4_y, r_body5_x, r_body5_y;
    wire [5:0]  r_body6_x, r_body6_y;
    wire [1:0]  r_direction;
    wire [3:0]  r_length;
    wire [1:0]  r_lives;
    wire [5:0]  food_x, food_y;
    wire [1:0]  last_turn_source, last_player_cmd;
    wire        dbg_p_turn_accepted, dbg_r_dir_changed;
    wire        dbg_p_collision, dbg_r_collision;
    wire        dbg_p_ate, dbg_r_ate;

    // Rival AI (combinational)
    wire [1:0] rival_turn_req;

    rival_ai_simple u_ai (
        .r_direction(r_direction),
        .r_head_x(r_head_x), .r_head_y(r_head_y),
        .r_body0_x(r_body0_x), .r_body0_y(r_body0_y),
        .r_body1_x(r_body1_x), .r_body1_y(r_body1_y),
        .r_body2_x(r_body2_x), .r_body2_y(r_body2_y),
        .r_body3_x(r_body3_x), .r_body3_y(r_body3_y),
        .r_body4_x(r_body4_x), .r_body4_y(r_body4_y),
        .r_body5_x(r_body5_x), .r_body5_y(r_body5_y),
        .r_body6_x(r_body6_x), .r_body6_y(r_body6_y),
        .r_length(r_length),
        .p_head_x(p_head_x), .p_head_y(p_head_y),
        .p_body0_x(p_body0_x), .p_body0_y(p_body0_y),
        .p_body1_x(p_body1_x), .p_body1_y(p_body1_y),
        .p_body2_x(p_body2_x), .p_body2_y(p_body2_y),
        .p_body3_x(p_body3_x), .p_body3_y(p_body3_y),
        .p_body4_x(p_body4_x), .p_body4_y(p_body4_y),
        .p_body5_x(p_body5_x), .p_body5_y(p_body5_y),
        .p_body6_x(p_body6_x), .p_body6_y(p_body6_y),
        .p_length(p_length),
        .food_x(food_x), .food_y(food_y),
        .rival_turn_req(rival_turn_req)
    );

    snake_game_core dut (
        .clk(clk), .reset_n(reset_n),
        .game_tick(game_tick), .start_btn(start_btn), .pause_sw(pause_sw),
        .player_turn_req(player_turn_req), .player_turn_valid(player_turn_valid),
        .turn_source_in(turn_source_in),
        .rival_turn_req(rival_turn_req),
        .fsm_state(fsm_state),
        .p_head_x(p_head_x), .p_head_y(p_head_y),
        .p_body0_x(p_body0_x), .p_body0_y(p_body0_y),
        .p_body1_x(p_body1_x), .p_body1_y(p_body1_y),
        .p_body2_x(p_body2_x), .p_body2_y(p_body2_y),
        .p_body3_x(p_body3_x), .p_body3_y(p_body3_y),
        .p_body4_x(p_body4_x), .p_body4_y(p_body4_y),
        .p_body5_x(p_body5_x), .p_body5_y(p_body5_y),
        .p_body6_x(p_body6_x), .p_body6_y(p_body6_y),
        .p_direction(p_direction), .p_length(p_length), .p_lives(p_lives),
        .r_head_x(r_head_x), .r_head_y(r_head_y),
        .r_body0_x(r_body0_x), .r_body0_y(r_body0_y),
        .r_body1_x(r_body1_x), .r_body1_y(r_body1_y),
        .r_body2_x(r_body2_x), .r_body2_y(r_body2_y),
        .r_body3_x(r_body3_x), .r_body3_y(r_body3_y),
        .r_body4_x(r_body4_x), .r_body4_y(r_body4_y),
        .r_body5_x(r_body5_x), .r_body5_y(r_body5_y),
        .r_body6_x(r_body6_x), .r_body6_y(r_body6_y),
        .r_direction(r_direction), .r_length(r_length), .r_lives(r_lives),
        .food_x(food_x), .food_y(food_y),
        .last_turn_source(last_turn_source), .last_player_cmd(last_player_cmd),
        .dbg_p_turn_accepted(dbg_p_turn_accepted),
        .dbg_r_dir_changed(dbg_r_dir_changed),
        .dbg_p_collision(dbg_p_collision),
        .dbg_r_collision(dbg_r_collision),
        .dbg_p_ate(dbg_p_ate),
        .dbg_r_ate(dbg_r_ate)
    );

    always #20 clk = ~clk;  // 25 MHz (40ns period)

    integer pass_count = 0;
    integer fail_count = 0;

    task pulse_start;
        begin
            @(posedge clk); start_btn <= 1'b1;
            @(posedge clk); start_btn <= 1'b0;
        end
    endtask

    task pulse_tick;
        begin
            @(posedge clk); game_tick <= 1'b1;
            @(posedge clk); game_tick <= 1'b0;
            @(posedge clk); // settle
        end
    endtask

    task send_turn;
        input [1:0] req;
        begin
            @(posedge clk);
            player_turn_req <= req;
            player_turn_valid <= 1'b1;
            turn_source_in <= 2'b01;
            @(posedge clk);
            player_turn_valid <= 1'b0;
        end
    endtask

    task check_val;
        input [31:0] actual;
        input [31:0] expected;
        input [159:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s: got %0d expected %0d", label, actual, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== tb_snake_game_core ===");
        clk = 0; reset_n = 0;
        game_tick = 0; start_btn = 0; pause_sw = 0;
        player_turn_req = 2'b00; player_turn_valid = 0;
        turn_source_in = 2'b00;

        // Reset
        #100; reset_n = 1;
        @(posedge clk);

        // -----------------------------------------------
        // Scenario 1: FSM transitions
        // -----------------------------------------------
        $display("\n--- Scenario 1: FSM transitions ---");
        check_val(fsm_state, 3'd0, "S1a:IDLE");

        // Start -> PLAYING
        pulse_start;
        @(posedge clk);
        check_val(fsm_state, 3'd1, "S1b:PLAYING");

        // Pause -> PAUSED
        pause_sw = 1;
        @(posedge clk); @(posedge clk);
        check_val(fsm_state, 3'd2, "S1c:PAUSED");

        // Unpause -> PLAYING
        pause_sw = 0;
        @(posedge clk); @(posedge clk);
        check_val(fsm_state, 3'd1, "S1d:UNPAUSED");

        // -----------------------------------------------
        // Scenario 2: Player movement (3 ticks right)
        // -----------------------------------------------
        $display("\n--- Scenario 2: Player movement ---");
        // Player starts at head=(5,5) body0=(4,5) dir=right, len=2
        check_val(p_head_x, 6'd5, "S2a:init_hx");
        check_val(p_head_y, 6'd5, "S2b:init_hy");
        check_val(p_length, 4'd2, "S2c:init_len");

        // Tick 1: move right to (6,5)
        pulse_tick;
        check_val(p_head_x, 6'd6, "S2d:tick1_hx");
        check_val(p_body0_x, 6'd5, "S2e:tick1_b0x");

        // Tick 2: move right to (7,5)
        pulse_tick;
        check_val(p_head_x, 6'd7, "S2f:tick2_hx");
        check_val(p_body0_x, 6'd6, "S2g:tick2_b0x");

        // -----------------------------------------------
        // Scenario 3: Turn latch
        // -----------------------------------------------
        $display("\n--- Scenario 3: Turn latch ---");
        // Send left turn (becomes down: right-1=down? no, dir_encoding: 00=up,01=right,10=down,11=left)
        // left turn = direction - 1 = 01 - 1 = 00 = up
        send_turn(2'b01);  // left relative
        pulse_tick;
        check_val(p_direction, 2'b00, "S3a:turn_up");  // was right(01), turn left -> up(00)

        // Now moving up: head should go from (8,5) to (8,4)
        pulse_tick;
        check_val(p_head_y, 6'd3, "S3b:move_up_y");

        // -----------------------------------------------
        // Scenario 4: Wall collision + life loss + respawn
        // -----------------------------------------------
        $display("\n--- Scenario 4: Wall collision ---");
        // Head is at (8,3), direction=up. Need to reach y=0 then try to go further.
        // Move up: y=3->2->1->0, then collision at y=0 moving up
        pulse_tick; // y=2
        pulse_tick; // y=1
        pulse_tick; // y=0
        check_val(p_head_y, 6'd0, "S4a:at_wall");
        // Next tick: wall collision
        pulse_tick;
        check_val(p_lives, 2'd2, "S4b:lives_dec");
        check_val(p_length, 4'd2, "S4c:respawn_len");
        check_val(p_head_x, 6'd5, "S4d:respawn_hx");
        check_val(p_head_y, 6'd5, "S4e:respawn_hy");
        check_val(p_direction, 2'b01, "S4f:respawn_dir");

        // -----------------------------------------------
        // Scenario 5: Food collection (FC0 at (14,10))
        // -----------------------------------------------
        $display("\n--- Scenario 5: Food collection ---");
        // Player at (5,5) dir=right after S4 respawn. Obstacles at x=16..20,y=5 (Seg4).
        // Navigate: right 1 tick, turn down, go to y=10, turn right, go to x=14 for food.
        pulse_tick; // x=6, y=5
        // Turn right-relative (right+1=down)
        send_turn(2'b10);
        pulse_tick; // dir=down, head at (6,6)
        check_val(p_direction, 2'b10, "S5a:turned_down");
        pulse_tick; // (6,7)
        pulse_tick; // (6,8)
        pulse_tick; // (6,9)
        pulse_tick; // (6,10)
        // Turn left-relative from down (down-1=right)
        send_turn(2'b01);
        pulse_tick; // dir=right, head at (7,10)
        pulse_tick; // (8,10)
        pulse_tick; // (9,10)
        pulse_tick; // (10,10)
        pulse_tick; // (11,10)
        pulse_tick; // (12,10) -- obstacle at (12,10)! Seg1 ends here.
        // Wait -- (12,10) IS an obstacle in the new map (Seg1: x=12, y=6..10).
        // Player will collide with obstacle at (12,10) and lose a life!
        // This is actually correct: the player hits obstacle, loses life 2->1, respawns.
        check_val(p_lives, 2'd1, "S5a2:obs_collision");
        check_val(p_head_x, 6'd5, "S5a3:respawn_hx");
        check_val(p_head_y, 6'd5, "S5a4:respawn_hy");

        // Try again: navigate below Seg1 (which is at x=12, y=6..10).
        // Go right to x=10, turn down to y=11 (below Seg1), turn right past x=12, continue to (14,10).
        // Actually, go right 5 ticks to x=10, turn down to y=11, turn right to x=14, turn up to y=10.
        // From (5,5) dir=right:
        pulse_tick; // (6,5)
        pulse_tick; // (7,5)
        pulse_tick; // (8,5)
        pulse_tick; // (9,5)
        pulse_tick; // (10,5)
        // Turn down
        send_turn(2'b10); // right+1=down
        pulse_tick; // (10,6)
        pulse_tick; // (10,7)
        pulse_tick; // (10,8)
        pulse_tick; // (10,9)
        pulse_tick; // (10,10)
        pulse_tick; // (10,11)
        // Turn right
        send_turn(2'b01); // down-1=right
        pulse_tick; // (11,11)
        pulse_tick; // (12,11)
        pulse_tick; // (13,11)
        pulse_tick; // (14,11)
        // Turn up
        send_turn(2'b01); // right-1=up
        pulse_tick; // (14,10) -- food! FC0 at (14,10)
        check_val(p_head_x, 6'd14, "S5b:ate_hx");
        check_val(p_head_y, 6'd10, "S5c:ate_hy");
        check_val(p_length, 4'd3, "S5d:grew");

        // -----------------------------------------------
        // Scenario 6: Restart from terminal
        // -----------------------------------------------
        $display("\n--- Scenario 6: Restart ---");
        // Player at (14,10) dir=up, lives=1. y=10 row clear to right (Seg2 at y=11).
        // Turn right-relative from up (up+1=right), then go to wall.
        send_turn(2'b10); // up+1=right
        pulse_tick; // (15,10) dir=right
        // x=15 to x=39 = 24 ticks
        repeat(24) pulse_tick; // reach x=39
        pulse_tick; // wall collision, lives 1->0 -> GAME_OVER
        check_val(p_lives, 2'd0, "S6b:lives_0");
        check_val(fsm_state, 3'd4, "S6c:GAME_OVER");

        // Movement should freeze
        pulse_tick;
        check_val(fsm_state, 3'd4, "S6d:frozen");

        // Restart
        pulse_start;
        @(posedge clk);
        // Goes to IDLE first, need another start for PLAYING
        check_val(fsm_state, 3'd0, "S6e:restart_idle");
        pulse_start;
        @(posedge clk);
        check_val(fsm_state, 3'd1, "S6f:restart_playing");
        check_val(p_lives, 2'd3, "S6g:fresh_lives");
        check_val(p_length, 4'd2, "S6h:fresh_len");

        // -----------------------------------------------
        // Summary
        // -----------------------------------------------
        $display("\n===========================");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
