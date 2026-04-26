`timescale 1ns / 1ps

module tb_snake_game_core_w4;

    reg clk, reset_n;
    reg game_tick, start_btn, pause_sw;
    reg [1:0] player_turn_req;
    reg       player_turn_valid;
    reg [1:0] turn_source_in;
    reg [1:0] rival_turn_req;

    wire [2:0] fsm_state;
    wire [5:0] p_head_x, p_head_y, p_body0_x, p_body0_y, p_body1_x, p_body1_y;
    wire [5:0] p_body2_x, p_body2_y, p_body3_x, p_body3_y, p_body4_x, p_body4_y;
    wire [5:0] p_body5_x, p_body5_y, p_body6_x, p_body6_y;
    wire [1:0] p_direction, p_lives;
    wire [3:0] p_length;
    wire [5:0] r_head_x, r_head_y, r_body0_x, r_body0_y, r_body1_x, r_body1_y;
    wire [5:0] r_body2_x, r_body2_y, r_body3_x, r_body3_y, r_body4_x, r_body4_y;
    wire [5:0] r_body5_x, r_body5_y, r_body6_x, r_body6_y;
    wire [1:0] r_direction, r_lives;
    wire [3:0] r_length;
    wire [5:0] food_x, food_y;
    wire [1:0] last_turn_source, last_player_cmd;
    wire anim_p_dying, anim_r_dying, anim_food_eaten;
    wire dbg_p_turn_accepted, dbg_r_dir_changed, dbg_p_collision, dbg_r_collision, dbg_p_ate, dbg_r_ate;

    wire       pending_valid = dut.pending_valid;
    wire [1:0] pending_turn  = dut.pending_turn;
    wire [1:0] pending_source = dut.pending_source;

    snake_game_core dut (
        .clk(clk), .reset_n(reset_n), .game_tick(game_tick), .start_btn(start_btn), .pause_sw(pause_sw),
        .player_turn_req(player_turn_req), .player_turn_valid(player_turn_valid), .turn_source_in(turn_source_in),
        .rival_turn_req(rival_turn_req), .fsm_state(fsm_state),
        .p_head_x(p_head_x), .p_head_y(p_head_y), .p_body0_x(p_body0_x), .p_body0_y(p_body0_y),
        .p_body1_x(p_body1_x), .p_body1_y(p_body1_y), .p_body2_x(p_body2_x), .p_body2_y(p_body2_y),
        .p_body3_x(p_body3_x), .p_body3_y(p_body3_y), .p_body4_x(p_body4_x), .p_body4_y(p_body4_y),
        .p_body5_x(p_body5_x), .p_body5_y(p_body5_y), .p_body6_x(p_body6_x), .p_body6_y(p_body6_y),
        .p_direction(p_direction), .p_length(p_length), .p_lives(p_lives),
        .r_head_x(r_head_x), .r_head_y(r_head_y), .r_body0_x(r_body0_x), .r_body0_y(r_body0_y),
        .r_body1_x(r_body1_x), .r_body1_y(r_body1_y), .r_body2_x(r_body2_x), .r_body2_y(r_body2_y),
        .r_body3_x(r_body3_x), .r_body3_y(r_body3_y), .r_body4_x(r_body4_x), .r_body4_y(r_body4_y),
        .r_body5_x(r_body5_x), .r_body5_y(r_body5_y), .r_body6_x(r_body6_x), .r_body6_y(r_body6_y),
        .r_direction(r_direction), .r_length(r_length), .r_lives(r_lives),
        .food_x(food_x), .food_y(food_y), .last_turn_source(last_turn_source), .last_player_cmd(last_player_cmd),
        .anim_p_dying(anim_p_dying), .anim_r_dying(anim_r_dying), .anim_food_eaten(anim_food_eaten),
        .dbg_p_turn_accepted(dbg_p_turn_accepted), .dbg_r_dir_changed(dbg_r_dir_changed),
        .dbg_p_collision(dbg_p_collision), .dbg_r_collision(dbg_r_collision),
        .dbg_p_ate(dbg_p_ate), .dbg_r_ate(dbg_r_ate)
    );

    always #20 clk = ~clk;

    integer pass_count, fail_count;

    task check;
        input condition;
        input [159:0] label;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL W4 %0s at %0t: state=%0d tick=%b turn_valid=%b pending=%b dir=%b head=(%0d,%0d) pause=%b",
                    label, $time, fsm_state, game_tick, player_turn_valid,
                    pending_valid, p_direction, p_head_x, p_head_y, pause_sw);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W4 %0s at %0t: state=%0d tick=%b turn_valid=%b pending=%b dir=%b head=(%0d,%0d) pause=%b",
                    label, $time, fsm_state, game_tick, player_turn_valid,
                    pending_valid, p_direction, p_head_x, p_head_y, pause_sw);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk); start_btn = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); start_btn = 1'b0;
        end
    endtask

    task pulse_tick;
        begin
            @(negedge clk); game_tick = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); game_tick = 1'b0;
        end
    endtask

    task send_turn;
        input [1:0] req;
        input [1:0] source;
        begin
            @(negedge clk);
            player_turn_req = req;
            player_turn_valid = 1'b1;
            turn_source_in = source;
            @(posedge clk); #1;
            @(negedge clk);
            player_turn_valid = 1'b0;
            turn_source_in = 2'b00;
        end
    endtask

    initial begin
        $display("=== W4 tb_snake_game_core_w4 ===");
        clk = 0; reset_n = 0; game_tick = 0; start_btn = 0; pause_sw = 0;
        player_turn_req = 2'b00; player_turn_valid = 0; turn_source_in = 2'b00;
        rival_turn_req = 2'b11;
        pass_count = 0; fail_count = 0;

        repeat (4) @(posedge clk);
        @(negedge clk); reset_n = 1'b1;
        repeat (2) @(posedge clk); #1;
        check(fsm_state == 3'd0, "reset_to_idle");

        pulse_start;
        check(fsm_state == 3'd6, "first_start_enters_title");

        pulse_start;
        check(fsm_state == 3'd1, "second_start_enters_playing");
        check(p_head_x == 6'd5 && p_head_y == 6'd5 && p_direction == 2'b01, "initial_player_state");

        send_turn(2'b01, 2'b01);
        check(pending_valid == 1'b1 && pending_turn == 2'b01 && pending_source == 2'b01, "turn_latched_before_tick");
        check(p_direction == 2'b01 && p_head_x == 6'd5 && p_head_y == 6'd5, "no_movement_before_tick");

        pulse_tick;
        check(dbg_p_turn_accepted == 1'b1, "turn_accepted_pulse");
        check(pending_valid == 1'b0, "pending_cleared_on_tick");
        check(p_direction == 2'b00 && p_head_x == 6'd5 && p_head_y == 6'd4, "direction_changes_only_on_tick");

        @(negedge clk); pause_sw = 1'b1;
        @(posedge clk); #1;
        check(fsm_state == 3'd2, "pause_state_entered");
        pulse_tick;
        check(p_head_x == 6'd5 && p_head_y == 6'd4, "paused_tick_does_not_move");

        @(negedge clk); pause_sw = 1'b0;
        @(posedge clk); #1;
        check(fsm_state == 3'd1, "resume_to_playing");

        $display("W4 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("W4 ALL TESTS PASSED");
            $finish;
        end else begin
            $display("W4 SOME TESTS FAILED");
            $fatal;
        end
    end

endmodule

module tb_snake_game_core_w5;

    reg clk, reset_n;
    reg game_tick, start_btn, pause_sw;
    reg [1:0] player_turn_req;
    reg       player_turn_valid;
    reg [1:0] turn_source_in;
    reg [1:0] rival_turn_req;

    wire [2:0] fsm_state;
    wire [5:0] p_head_x, p_head_y, p_body0_x, p_body0_y, p_body1_x, p_body1_y;
    wire [5:0] p_body2_x, p_body2_y, p_body3_x, p_body3_y, p_body4_x, p_body4_y;
    wire [5:0] p_body5_x, p_body5_y, p_body6_x, p_body6_y;
    wire [1:0] p_direction, p_lives;
    wire [3:0] p_length;
    wire [5:0] r_head_x, r_head_y, r_body0_x, r_body0_y, r_body1_x, r_body1_y;
    wire [5:0] r_body2_x, r_body2_y, r_body3_x, r_body3_y, r_body4_x, r_body4_y;
    wire [5:0] r_body5_x, r_body5_y, r_body6_x, r_body6_y;
    wire [1:0] r_direction, r_lives;
    wire [3:0] r_length;
    wire [5:0] food_x, food_y;
    wire [1:0] last_turn_source, last_player_cmd;
    wire anim_p_dying, anim_r_dying, anim_food_eaten;
    wire dbg_p_turn_accepted, dbg_r_dir_changed, dbg_p_collision, dbg_r_collision, dbg_p_ate, dbg_r_ate;

    wire       p_collision = dut.p_collided;
    wire [24:0] respawn_timer = dut.respawn_timer;
    wire       p_dying = anim_p_dying;
    wire       game_over = (fsm_state == 3'd4);

    snake_game_core #(
        .INITIAL_LIVES(2),
        .RESPAWN_TICKS(25'd6),
        .P_INIT_HEAD_X(6'd1),
        .P_INIT_HEAD_Y(6'd1),
        .P_INIT_BODY0_X(6'd1),
        .P_INIT_BODY0_Y(6'd2),
        .P_INIT_DIR(2'b00),
        .R_INIT_HEAD_X(6'd30),
        .R_INIT_HEAD_Y(6'd18),
        .R_INIT_BODY0_X(6'd31),
        .R_INIT_BODY0_Y(6'd18),
        .R_INIT_DIR(2'b11)
    ) dut (
        .clk(clk), .reset_n(reset_n), .game_tick(game_tick), .start_btn(start_btn), .pause_sw(pause_sw),
        .player_turn_req(player_turn_req), .player_turn_valid(player_turn_valid), .turn_source_in(turn_source_in),
        .rival_turn_req(rival_turn_req), .fsm_state(fsm_state),
        .p_head_x(p_head_x), .p_head_y(p_head_y), .p_body0_x(p_body0_x), .p_body0_y(p_body0_y),
        .p_body1_x(p_body1_x), .p_body1_y(p_body1_y), .p_body2_x(p_body2_x), .p_body2_y(p_body2_y),
        .p_body3_x(p_body3_x), .p_body3_y(p_body3_y), .p_body4_x(p_body4_x), .p_body4_y(p_body4_y),
        .p_body5_x(p_body5_x), .p_body5_y(p_body5_y), .p_body6_x(p_body6_x), .p_body6_y(p_body6_y),
        .p_direction(p_direction), .p_length(p_length), .p_lives(p_lives),
        .r_head_x(r_head_x), .r_head_y(r_head_y), .r_body0_x(r_body0_x), .r_body0_y(r_body0_y),
        .r_body1_x(r_body1_x), .r_body1_y(r_body1_y), .r_body2_x(r_body2_x), .r_body2_y(r_body2_y),
        .r_body3_x(r_body3_x), .r_body3_y(r_body3_y), .r_body4_x(r_body4_x), .r_body4_y(r_body4_y),
        .r_body5_x(r_body5_x), .r_body5_y(r_body5_y), .r_body6_x(r_body6_x), .r_body6_y(r_body6_y),
        .r_direction(r_direction), .r_length(r_length), .r_lives(r_lives),
        .food_x(food_x), .food_y(food_y), .last_turn_source(last_turn_source), .last_player_cmd(last_player_cmd),
        .anim_p_dying(anim_p_dying), .anim_r_dying(anim_r_dying), .anim_food_eaten(anim_food_eaten),
        .dbg_p_turn_accepted(dbg_p_turn_accepted), .dbg_r_dir_changed(dbg_r_dir_changed),
        .dbg_p_collision(dbg_p_collision), .dbg_r_collision(dbg_r_collision),
        .dbg_p_ate(dbg_p_ate), .dbg_r_ate(dbg_r_ate)
    );

    always #20 clk = ~clk;

    integer pass_count, fail_count;

    task check;
        input condition;
        input [159:0] label;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL W5 %0s at %0t: state=%0d tick=%b head=(%0d,%0d) dir=%b collision=%b dbg_collision=%b lives=%0d dying=%b respawn_timer=%0d game_over=%b",
                    label, $time, fsm_state, game_tick, p_head_x, p_head_y,
                    p_direction, p_collision, dbg_p_collision, p_lives,
                    p_dying, respawn_timer, game_over);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W5 %0s at %0t: state=%0d tick=%b head=(%0d,%0d) dir=%b collision=%b dbg_collision=%b lives=%0d dying=%b respawn_timer=%0d game_over=%b",
                    label, $time, fsm_state, game_tick, p_head_x, p_head_y,
                    p_direction, p_collision, dbg_p_collision, p_lives,
                    p_dying, respawn_timer, game_over);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk); start_btn = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); start_btn = 1'b0;
        end
    endtask

    task pulse_tick;
        begin
            @(negedge clk); game_tick = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); game_tick = 1'b0;
        end
    endtask

    initial begin
        $display("=== W5 tb_snake_game_core_w5 ===");
        clk = 0; reset_n = 0; game_tick = 0; start_btn = 0; pause_sw = 0;
        player_turn_req = 2'b00; player_turn_valid = 0; turn_source_in = 2'b00;
        rival_turn_req = 2'b11;
        pass_count = 0; fail_count = 0;

        repeat (4) @(posedge clk);
        @(negedge clk); reset_n = 1'b1;
        repeat (2) @(posedge clk); #1;
        pulse_start;
        pulse_start;
        check(fsm_state == 3'd1 && p_lives == 2'd2, "playing_two_lives");

        pulse_tick;
        check(p_head_y == 6'd0 && fsm_state == 3'd1, "move_to_top_edge");

        pulse_tick;
        check(p_collision == 1'b1 && dbg_p_collision == 1'b1, "collision_flag_pulses");
        check(p_lives == 2'd1 && fsm_state == 3'd5 && p_dying == 1'b1, "life_loss_enters_respawning");

        repeat (8) @(posedge clk);
        #1;
        check(fsm_state == 3'd1, "respawn_returns_to_playing");
        check(p_head_x == 6'd1 && p_head_y == 6'd1 && p_length == 4'd2 && p_direction == 2'b00, "respawn_restores_position_length_dir");
        check(p_lives == 2'd1, "respawn_keeps_lost_life");

        pulse_tick;
        check(p_head_y == 6'd0, "last_life_reaches_top_edge");

        pulse_tick;
        check(dbg_p_collision == 1'b1 && p_lives == 2'd0 && game_over == 1'b1, "final_collision_enters_game_over");

        $display("W5 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("W5 ALL TESTS PASSED");
            $finish;
        end else begin
            $display("W5 SOME TESTS FAILED");
            $fatal;
        end
    end

endmodule

module tb_snake_game_core_w6;

    reg clk, reset_n;
    reg game_tick, start_btn, pause_sw;
    reg [1:0] player_turn_req;
    reg       player_turn_valid;
    reg [1:0] turn_source_in;
    reg [1:0] rival_turn_req;

    wire [2:0] fsm_state;
    wire [5:0] p_head_x, p_head_y, p_body0_x, p_body0_y, p_body1_x, p_body1_y;
    wire [5:0] p_body2_x, p_body2_y, p_body3_x, p_body3_y, p_body4_x, p_body4_y;
    wire [5:0] p_body5_x, p_body5_y, p_body6_x, p_body6_y;
    wire [1:0] p_direction, p_lives;
    wire [3:0] p_length;
    wire [5:0] r_head_x, r_head_y, r_body0_x, r_body0_y, r_body1_x, r_body1_y;
    wire [5:0] r_body2_x, r_body2_y, r_body3_x, r_body3_y, r_body4_x, r_body4_y;
    wire [5:0] r_body5_x, r_body5_y, r_body6_x, r_body6_y;
    wire [1:0] r_direction, r_lives;
    wire [3:0] r_length;
    wire [5:0] food_x, food_y;
    wire [1:0] last_turn_source, last_player_cmd;
    wire anim_p_dying, anim_r_dying, anim_food_eaten;
    wire dbg_p_turn_accepted, dbg_r_dir_changed, dbg_p_collision, dbg_r_collision, dbg_p_ate, dbg_r_ate;

    wire [2:0] food_idx = dut.food_idx;
    wire       p_score_proxy = (p_length > 4'd2);

    snake_game_core #(
        .P_INIT_HEAD_X(6'd13),
        .P_INIT_HEAD_Y(6'd10),
        .P_INIT_BODY0_X(6'd13),
        .P_INIT_BODY0_Y(6'd9),
        .P_INIT_DIR(2'b01),
        .R_INIT_HEAD_X(6'd34),
        .R_INIT_HEAD_Y(6'd17),
        .R_INIT_BODY0_X(6'd35),
        .R_INIT_BODY0_Y(6'd17),
        .R_INIT_DIR(2'b11)
    ) dut (
        .clk(clk), .reset_n(reset_n), .game_tick(game_tick), .start_btn(start_btn), .pause_sw(pause_sw),
        .player_turn_req(player_turn_req), .player_turn_valid(player_turn_valid), .turn_source_in(turn_source_in),
        .rival_turn_req(rival_turn_req), .fsm_state(fsm_state),
        .p_head_x(p_head_x), .p_head_y(p_head_y), .p_body0_x(p_body0_x), .p_body0_y(p_body0_y),
        .p_body1_x(p_body1_x), .p_body1_y(p_body1_y), .p_body2_x(p_body2_x), .p_body2_y(p_body2_y),
        .p_body3_x(p_body3_x), .p_body3_y(p_body3_y), .p_body4_x(p_body4_x), .p_body4_y(p_body4_y),
        .p_body5_x(p_body5_x), .p_body5_y(p_body5_y), .p_body6_x(p_body6_x), .p_body6_y(p_body6_y),
        .p_direction(p_direction), .p_length(p_length), .p_lives(p_lives),
        .r_head_x(r_head_x), .r_head_y(r_head_y), .r_body0_x(r_body0_x), .r_body0_y(r_body0_y),
        .r_body1_x(r_body1_x), .r_body1_y(r_body1_y), .r_body2_x(r_body2_x), .r_body2_y(r_body2_y),
        .r_body3_x(r_body3_x), .r_body3_y(r_body3_y), .r_body4_x(r_body4_x), .r_body4_y(r_body4_y),
        .r_body5_x(r_body5_x), .r_body5_y(r_body5_y), .r_body6_x(r_body6_x), .r_body6_y(r_body6_y),
        .r_direction(r_direction), .r_length(r_length), .r_lives(r_lives),
        .food_x(food_x), .food_y(food_y), .last_turn_source(last_turn_source), .last_player_cmd(last_player_cmd),
        .anim_p_dying(anim_p_dying), .anim_r_dying(anim_r_dying), .anim_food_eaten(anim_food_eaten),
        .dbg_p_turn_accepted(dbg_p_turn_accepted), .dbg_r_dir_changed(dbg_r_dir_changed),
        .dbg_p_collision(dbg_p_collision), .dbg_r_collision(dbg_r_collision),
        .dbg_p_ate(dbg_p_ate), .dbg_r_ate(dbg_r_ate)
    );

    always #20 clk = ~clk;

    integer pass_count, fail_count;

    function known3;
        input [2:0] value;
        begin
            known3 = (^value !== 1'bx);
        end
    endfunction

    function known6;
        input [5:0] value;
        begin
            known6 = (^value !== 1'bx);
        end
    endfunction

    task check;
        input condition;
        input [159:0] label;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL W6 %0s at %0t: state=%0d tick=%b head=(%0d,%0d) food=(%0d,%0d) food_idx=%0d ate=%b len=%0d rival_len=%0d",
                    label, $time, fsm_state, game_tick, p_head_x, p_head_y,
                    food_x, food_y, food_idx, dbg_p_ate, p_length, r_length);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W6 %0s at %0t: state=%0d tick=%b head=(%0d,%0d) food=(%0d,%0d) food_idx=%0d ate=%b len=%0d rival_len=%0d",
                    label, $time, fsm_state, game_tick, p_head_x, p_head_y,
                    food_x, food_y, food_idx, dbg_p_ate, p_length, r_length);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk); start_btn = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); start_btn = 1'b0;
        end
    endtask

    task pulse_tick;
        begin
            @(negedge clk); game_tick = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); game_tick = 1'b0;
        end
    endtask

    initial begin
        $display("=== W6 tb_snake_game_core_w6 ===");
        clk = 0; reset_n = 0; game_tick = 0; start_btn = 0; pause_sw = 0;
        player_turn_req = 2'b00; player_turn_valid = 0; turn_source_in = 2'b00;
        rival_turn_req = 2'b11;
        pass_count = 0; fail_count = 0;

        repeat (4) @(posedge clk);
        @(negedge clk); reset_n = 1'b1;
        repeat (2) @(posedge clk); #1;
        pulse_start;
        pulse_start;

        check(fsm_state == 3'd1 && p_head_x == 6'd13 && p_head_y == 6'd10, "spawn_one_tile_before_food");
        check(food_x == 6'd14 && food_y == 6'd10 && food_idx == 3'd0, "initial_food_candidate");

        pulse_tick;
        check(dbg_p_ate == 1'b1 && anim_food_eaten == 1'b1, "ate_pulse");
        check(p_head_x == 6'd14 && p_head_y == 6'd10, "head_enters_food_tile");
        check(p_length == 4'd3 && p_score_proxy == 1'b1, "length_increases");
        check(known3(food_idx) && known6(food_x) && known6(food_y), "food_outputs_known_after_eat");
        check(food_idx == 3'd1 && food_x == 6'd25 && food_y == 6'd5, "food_relocated_to_fc1");
        check(r_length == 4'd2, "rival_length_unchanged");

        $display("W6 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("W6 ALL TESTS PASSED");
            $finish;
        end else begin
            $display("W6 SOME TESTS FAILED");
            $fatal;
        end
    end

endmodule
