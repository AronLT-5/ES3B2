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
        // Scenario 5: Food collection
        // -----------------------------------------------
        $display("\n--- Scenario 5: Food collection ---");
        // Food starts at (12,10). Player at (5,5) dir=right.
        // Move right 7 ticks to reach x=12
        pulse_tick; // x=6
        pulse_tick; // x=7
        pulse_tick; // x=8
        pulse_tick; // x=9
        pulse_tick; // x=10
        pulse_tick; // x=11
        // Now turn down toward food at y=10
        send_turn(2'b10);  // right relative: right(01)+1 = down(10)
        pulse_tick; // apply turn, move to (12,5)... wait, let me recalculate.
        // After respawn: head=(5,5) dir=right.
        // After 6 ticks right: head=(11,5). Then send right-turn to go down.
        // tick with turn applied: direction becomes 01+1=10(down), head=(11,6)? No...
        // Actually direction 01(right) + right_turn(+1) = 10(down).
        // But the turn was latched before the tick: next_p_dir = p_direction + 1 = 10(down)
        // So head moves down from (11,5) to (11,6)
        check_val(p_direction, 2'b10, "S5a:turned_down");

        // Continue down toward y=10: y=6->7->8->9->10
        pulse_tick; // y=7
        pulse_tick; // y=8
        pulse_tick; // y=9
        // Now turn right (which from down is left: 10+1=11=left).
        // Actually we want to go right to hit food at (12,10).
        // Current: head at (11,9), dir=down. Need to go to (12,10).
        // Turn left from down: down - 1 = right(01). That's a left-relative turn.
        // No wait. From dir=10(down), a left-relative turn (pending_turn=01) means dir = 10 - 1 = 01 = right.
        // So send left turn to go right.
        // Actually let me just let it go down one more to (11,10), then turn right.
        pulse_tick; // head now at (11,10)
        // Send left turn to go right: 10(down) - 1 = 01(right)
        send_turn(2'b01);
        pulse_tick; // head at (12,10) - should eat food!
        check_val(p_head_x, 6'd12, "S5b:ate_hx");
        check_val(p_head_y, 6'd10, "S5c:ate_hy");
        check_val(p_length, 4'd3, "S5d:grew");

        // -----------------------------------------------
        // Scenario 6: Restart from terminal
        // -----------------------------------------------
        $display("\n--- Scenario 6: Restart ---");
        // Force many wall collisions to kill player
        // Head at (12,10) dir=right. Move right to wall.
        // x=12 to x=39 = 27 ticks, then wall collision at x=39
        repeat(27) pulse_tick; // reach x=39
        pulse_tick; // wall collision, lives 2->1
        check_val(p_lives, 2'd1, "S6a:lives_1");

        // Move right to wall again (from respawn at x=5, need 34 ticks to x=39)
        repeat(34) pulse_tick;
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
