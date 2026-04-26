`timescale 1ns / 1ps

// W8: Info bar renderer testbench. Updated for the new HUD layout:
//   * Row 1 (Student IDs) at y=4
//   * Row 2 split score row at y=16 ("PLAYER SCORE : N" left, "N : SCORE RIVAL" right)
//   * Hearts at y=28 (Heart_Blue for player on the left, Heart_Red for rival on the right)
//   * Row 3 (MODE/SRC/CMD) at y=46
//   * Row 4 (state text) at y=60

module tb_info_bar_renderer;

    reg clk, reset_n;
    reg [9:0] pixel_x, pixel_y;
    reg       video_active;
    reg [2:0] fsm_state;
    reg [3:0] p_length, r_length;
    reg [1:0] p_lives, r_lives;
    reg [1:0] last_cmd, turn_source;
    reg       voice_mode_en;
    reg [11:0] heart_blue_data, heart_red_data;

    wire [7:0]  heart_blue_addr, heart_red_addr;
    wire        info_active;
    wire [11:0] info_rgb;
    wire [6:0]  glyph_char;
    wire [6:0]  char_code;

    assign glyph_char = dut.glyph_char;
    assign char_code = dut.glyph_char;

    info_bar_renderer dut (
        .clk(clk), .reset_n(reset_n),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .video_active(video_active),
        .fsm_state(fsm_state),
        .p_length(p_length), .p_lives(p_lives),
        .r_length(r_length), .r_lives(r_lives),
        .last_player_cmd(last_cmd),
        .last_turn_source(turn_source),
        .voice_mode_en(voice_mode_en),
        .heart_blue_addr(heart_blue_addr),
        .heart_blue_data(heart_blue_data),
        .heart_red_addr(heart_red_addr),
        .heart_red_data(heart_red_data),
        .info_active(info_active),
        .info_rgb(info_rgb)
    );

    always #20 clk = ~clk;

    integer pass_count, fail_count;

    task check;
        input condition;
        input [255:0] label;
        begin
            #1;
            if (!condition) begin
                $display("FAIL W8 %0s at %0t", label, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W8 %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== W8 tb_info_bar_renderer ===");
        clk = 0;
        reset_n = 0;
        pixel_x = 0;
        pixel_y = 0;
        video_active = 1'b1;
        fsm_state = 3'd1;
        p_length = 4'd5;       // -> p_score = 3
        r_length = 4'd2;       // -> r_score = 0
        p_lives = 2'd3;
        r_lives = 2'd3;
        last_cmd = 2'b00;
        turn_source = 2'b00;
        voice_mode_en = 1'b0;
        heart_blue_data = 12'h00F;  // blue
        heart_red_data  = 12'hF00;  // red
        pass_count = 0;
        fail_count = 0;

        repeat (3) @(posedge clk);
        reset_n = 1'b1;
        repeat (2) @(posedge clk);

        // Info bar boundary
        pixel_x = 10'd20;
        pixel_y = 10'd20;
        check(info_active == 1'b1 && info_rgb == 12'h112, "inside_top_100_uses_info_bar");

        pixel_y = 10'd100;
        check(info_active == 1'b0, "outside_top_100_inactive");

        // Row 1 (Student IDs) moved to y=4. ROW1_X = (640 - 19*6)/2 = 263.
        pixel_x = 10'd263;
        pixel_y = 10'd4;
        check(glyph_char == 7'h55, "student_id_row_u_at_y4");

        // Row 2 left: PLAYER SCORE : N at y=16, x=20..
        pixel_x = 10'd20;
        pixel_y = 10'd16;
        check(glyph_char == 7'h50, "row2_left_first_char_p");

        // Row 2 left score digit: index 15 -> x=20+15*6 = 110. p_length=5 -> score=3 -> '3'.
        pixel_x = 10'd110;
        check(glyph_char == 7'h33, "row2_left_score_digit_3");

        // Row 2 right: N : SCORE RIVAL right-aligned ending x=620.
        // ROW2_RIGHT_LEN=17, ROW2_RIGHT_X = 620 - 17*6 = 518.
        // Index 0 (the rival score digit) at x=518. r_length=2 -> score=0 -> '0'.
        pixel_x = 10'd518;
        pixel_y = 10'd16;
        check(glyph_char == 7'h30, "row2_right_score_digit_0");
        // Last char 'L' at index 15: x = 518 + 15*6 = 608.
        pixel_x = 10'd608;
        check(glyph_char == 7'h4C, "row2_right_last_char_l");

        // Row 3 mode (y=46)
        pixel_x = 10'd130;        // x=100 + 5*6 = 130 -> first char of BUTTON/VOICE field
        pixel_y = 10'd46;
        voice_mode_en = 1'b0;
        check(glyph_char == 7'h42, "row3_button_mode_b");
        voice_mode_en = 1'b1;
        check(glyph_char == 7'h56, "row3_voice_mode_v");

        // Row 3 source
        pixel_x = 10'd196;        // x=100 + 16*6 = 196
        pixel_y = 10'd46;
        turn_source = 2'b10;
        last_cmd = 2'b01;
        check(glyph_char == 7'h56, "row3_source_voice_v");

        // Row 3 last command (LEFT)
        pixel_x = 10'd244;        // x=100 + 24*6 = 244
        check(glyph_char == 7'h4C, "row3_last_cmd_left_l");

        // Row 4 state text at y=60. Index 0, x=200, GAME_OVER -> 'G' (0x47).
        pixel_x = 10'd200;
        pixel_y = 10'd60;
        fsm_state = 3'd4;
        check(glyph_char == 7'h47, "row4_game_over_g_at_y60");

        // Player heart (Heart_Blue) at y=28, x=20 -> addr 0, data should
        // override info bar background.
        pixel_x = 10'd20;
        pixel_y = 10'd28;
        fsm_state = 3'd1;
        p_lives = 2'd3;
        heart_blue_data = 12'h00F;
        check(info_active == 1'b1 && heart_blue_addr == 8'd0 && info_rgb == 12'h00F,
              "player_heart_overrides_bg");

        // Rival heart (Heart_Red) at y=28. R_HEART_X0 = 640 - 21 - 45 = 574.
        pixel_x = 10'd574;
        pixel_y = 10'd28;
        r_lives = 2'd3;
        heart_red_data = 12'hF00;
        check(info_active == 1'b1 && heart_red_addr == 8'd0 && info_rgb == 12'hF00,
              "rival_heart_overrides_bg");

        // Heart slot disappears when lives are depleted: with p_lives=0 the
        // first slot must NOT show the blue heart.
        pixel_x = 10'd20;
        pixel_y = 10'd28;
        p_lives = 2'd0;
        heart_blue_data = 12'h00F;
        check(info_rgb == 12'h112, "player_heart_hidden_when_no_lives");

        $display("W8 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("W8 ALL TESTS PASSED");
        else                 $display("W8 SOME TESTS FAILED");
        $finish;
    end

endmodule
