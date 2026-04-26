`timescale 1ns / 1ps

module tb_top_serpent_says;

    reg CLK100MHZ;
    reg CPU_RESETN;
    reg BTNC, BTNL, BTNR;
    reg [2:0] SW;
    reg pdm_data_i;

    wire pdm_clk_o, pdm_lrsel_o;
    wire VGA_HS, VGA_VS;
    wire [3:0] VGA_R, VGA_G, VGA_B;
    wire [12:0] LED;
    wire CA, CB, CC, CD, CE, CF, CG, DP;
    wire [7:0] AN;

    wire clk_25mhz = dut.clk_25mhz;
    wire [2:0] fsm_state = dut.fsm_state;
    wire game_tick = dut.game_tick;
    wire [1:0] turn_req = dut.player_turn_req;
    wire       turn_valid = dut.player_turn_valid;
    wire [5:0] p_head_x = dut.p_head_x;
    wire [5:0] p_head_y = dut.p_head_y;
    wire [1:0] p_direction = dut.p_direction;
    wire [1:0] turn_source = dut.turn_source;
    wire voice_mode_en = dut.voice_mode_en;
    wire [2:0] btn_c_l_r = {BTNC, BTNL, BTNR};
    wire [11:0] vga_rgb = {VGA_R, VGA_G, VGA_B};
    wire [6:0] seg_ca_cg = {CA, CB, CC, CD, CE, CF, CG};

    top_serpent_says #(
        .BUTTON_TICK_COUNT_MAX(16),
        .VOICE_TICK_COUNT_MAX(24),
        .INITIAL_LIVES(3)
    ) dut (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .BTNC(BTNC),
        .BTNL(BTNL),
        .BTNR(BTNR),
        .SW(SW),
        .pdm_data_i(pdm_data_i),
        .pdm_clk_o(pdm_clk_o),
        .pdm_lrsel_o(pdm_lrsel_o),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .LED(LED),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD), .CE(CE), .CF(CF), .CG(CG), .DP(DP),
        .AN(AN)
    );

    always #5 CLK100MHZ = ~CLK100MHZ;

    integer pass_count, fail_count;

    task check;
        input condition;
        input [159:0] label;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL W11 %0s at %0t", label, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W11 %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_known;
        input [63:0] value;
        input [159:0] label;
        begin
            if (^value === 1'bx) begin
                $display("FAIL W11 %0s contains X at %0t", label, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W11 %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task button_pulse;
        input integer which;
        begin
            @(negedge CLK100MHZ);
            case (which)
                0: BTNC = 1'b1;
                1: BTNL = 1'b1;
                2: BTNR = 1'b1;
            endcase
            repeat (50) @(posedge CLK100MHZ);
            case (which)
                0: BTNC = 1'b0;
                1: BTNL = 1'b0;
                2: BTNR = 1'b0;
            endcase
            repeat (20) @(posedge CLK100MHZ);
        end
    endtask

    task wait_25_cycles;
        input integer cycles;
        integer j;
        begin
            for (j = 0; j < cycles; j = j + 1)
                @(posedge clk_25mhz);
            #1;
        end
    endtask

    initial begin
        $display("=== W11 tb_top_serpent_says ===");
        CLK100MHZ = 0;
        CPU_RESETN = 0;
        BTNC = 0;
        BTNL = 0;
        BTNR = 0;
        SW = 3'b000;
        pdm_data_i = 0;
        pass_count = 0;
        fail_count = 0;

        dut.u_renderer.anim_cnt = 24'd0;
        dut.u_renderer.food_flash_cnt = 23'd0;
        dut.u_renderer.in_victory_banner = 1'b0;
        dut.u_renderer.in_gameover_banner = 1'b0;
        dut.u_renderer.in_logo = 1'b0;
        dut.u_renderer.in_title = 1'b0;

        repeat (20) @(posedge CLK100MHZ);
        CPU_RESETN = 1'b1;
        wait_25_cycles(8);
        check(fsm_state == 3'd0, "reset_to_idle");
        check_known({VGA_HS, VGA_VS, VGA_R, VGA_G, VGA_B}, "vga_known_after_reset");
        check_known({19'd0, LED}, "led_known_after_reset");

        button_pulse(0);
        wait_25_cycles(8);
        check(fsm_state == 3'd6, "first_start_title");

        button_pulse(0);
        wait_25_cycles(8);
        check(fsm_state == 3'd1, "second_start_playing");

        @(posedge game_tick);
        @(posedge game_tick);
        #1;
        check(p_head_x > 6'd5, "game_tick_moves_player");

        button_pulse(1);
        wait_25_cycles(8);
        check(turn_valid == 1'b1 || turn_req == 2'b01 || turn_source == 2'b01 ||
              dut.u_game_core.pending_valid == 1'b1 || p_direction == 2'b00 ||
              dut.last_turn_source == 2'b01, "button_turn_request_visible");
        @(posedge game_tick);
        #1;
        check(p_direction == 2'b00, "button_turn_changes_direction_on_tick");

        SW[0] = 1'b1;
        wait_25_cycles(5);
        check(fsm_state == 3'd2, "pause_switch_enters_paused");
        SW[0] = 1'b0;
        wait_25_cycles(5);
        check(fsm_state == 3'd1, "pause_release_resumes");

        SW[2] = 1'b1;
        wait_25_cycles(5);
        check(voice_mode_en == 1'b1 && LED[8] == 1'b1, "voice_mode_status_visible");
        SW[2] = 1'b0;

        wait_25_cycles(20);
        check_known({VGA_HS, VGA_VS, VGA_R, VGA_G, VGA_B}, "vga_outputs_known");
        check_known({19'd0, LED}, "led_known");
        check_known({23'd0, AN, CA, CB, CC, CD, CE, CF, CG, DP}, "seven_segment_known");

        $display("W11 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("W11 ALL TESTS PASSED");
        else                 $display("W11 SOME TESTS FAILED");
        $finish;
    end

endmodule
