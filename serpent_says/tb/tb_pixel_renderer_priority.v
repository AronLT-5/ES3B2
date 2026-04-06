`timescale 1ns / 1ps

// Tests rendering priority chain with fake sprite data.
// Does not require actual .mem files.

module tb_pixel_renderer_priority;

    reg        clk;
    reg  [9:0] pixel_x, pixel_y;
    reg        video_active;
    reg  [2:0] fsm_state;

    // Player snake state
    reg  [5:0] p_head_x, p_head_y;
    reg  [5:0] p_body0_x, p_body0_y, p_body1_x, p_body1_y;
    reg  [5:0] p_body2_x, p_body2_y, p_body3_x, p_body3_y;
    reg  [5:0] p_body4_x, p_body4_y, p_body5_x, p_body5_y;
    reg  [5:0] p_body6_x, p_body6_y;
    reg  [1:0] p_direction;
    reg  [3:0] p_length;

    // Rival snake state
    reg  [5:0] r_head_x, r_head_y;
    reg  [5:0] r_body0_x, r_body0_y, r_body1_x, r_body1_y;
    reg  [5:0] r_body2_x, r_body2_y, r_body3_x, r_body3_y;
    reg  [5:0] r_body4_x, r_body4_y, r_body5_x, r_body5_y;
    reg  [5:0] r_body6_x, r_body6_y;
    reg  [1:0] r_direction;
    reg  [3:0] r_length;

    reg  [5:0] food_x, food_y;

    // Info bar
    reg        info_active;
    reg  [11:0] info_rgb;

    // Fake sprite data
    reg  [11:0] p_head_sprite_data;
    wire [7:0]  p_head_sprite_addr;
    reg  [11:0] r_head_sprite_data;
    wire [7:0]  r_head_sprite_addr;
    reg  [11:0] food_sprite_data;
    wire [7:0]  food_sprite_addr;
    reg  [11:0] obstacle_sprite_data;
    wire [7:0]  obstacle_sprite_addr;
    reg  [11:0] victory_sprite_data;
    wire [13:0] victory_sprite_addr;
    reg  [11:0] gameover_sprite_data;
    wire [13:0] gameover_sprite_addr;

    wire [3:0] vga_r, vga_g, vga_b;

    pixel_renderer dut (
        .clk(clk),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .video_active(video_active),
        .fsm_state(fsm_state),
        .p_head_x(p_head_x), .p_head_y(p_head_y),
        .p_body0_x(p_body0_x), .p_body0_y(p_body0_y),
        .p_body1_x(p_body1_x), .p_body1_y(p_body1_y),
        .p_body2_x(p_body2_x), .p_body2_y(p_body2_y),
        .p_body3_x(p_body3_x), .p_body3_y(p_body3_y),
        .p_body4_x(p_body4_x), .p_body4_y(p_body4_y),
        .p_body5_x(p_body5_x), .p_body5_y(p_body5_y),
        .p_body6_x(p_body6_x), .p_body6_y(p_body6_y),
        .p_direction(p_direction), .p_length(p_length),
        .r_head_x(r_head_x), .r_head_y(r_head_y),
        .r_body0_x(r_body0_x), .r_body0_y(r_body0_y),
        .r_body1_x(r_body1_x), .r_body1_y(r_body1_y),
        .r_body2_x(r_body2_x), .r_body2_y(r_body2_y),
        .r_body3_x(r_body3_x), .r_body3_y(r_body3_y),
        .r_body4_x(r_body4_x), .r_body4_y(r_body4_y),
        .r_body5_x(r_body5_x), .r_body5_y(r_body5_y),
        .r_body6_x(r_body6_x), .r_body6_y(r_body6_y),
        .r_direction(r_direction), .r_length(r_length),
        .food_x(food_x), .food_y(food_y),
        .info_active(info_active), .info_rgb(info_rgb),
        .p_head_sprite_data(p_head_sprite_data),
        .p_head_sprite_addr(p_head_sprite_addr),
        .r_head_sprite_data(r_head_sprite_data),
        .r_head_sprite_addr(r_head_sprite_addr),
        .food_sprite_data(food_sprite_data),
        .food_sprite_addr(food_sprite_addr),
        .obstacle_sprite_data(obstacle_sprite_data),
        .obstacle_sprite_addr(obstacle_sprite_addr),
        .victory_sprite_data(victory_sprite_data),
        .victory_sprite_addr(victory_sprite_addr),
        .gameover_sprite_data(gameover_sprite_data),
        .gameover_sprite_addr(gameover_sprite_addr),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b)
    );

    always #20 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task check_rgb;
        input [3:0] exp_r, exp_g, exp_b;
        input [159:0] label;
        begin
            #1;
            if (vga_r !== exp_r || vga_g !== exp_g || vga_b !== exp_b) begin
                $display("FAIL %0s: got R=%h G=%h B=%h, expected R=%h G=%h B=%h",
                    label, vga_r, vga_g, vga_b, exp_r, exp_g, exp_b);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task init_state;
        begin
            // Place snakes and food out of the way
            p_head_x = 6'd2;  p_head_y = 6'd2;
            p_body0_x = 6'd1; p_body0_y = 6'd2;
            p_body1_x = 0; p_body1_y = 0;
            p_body2_x = 0; p_body2_y = 0;
            p_body3_x = 0; p_body3_y = 0;
            p_body4_x = 0; p_body4_y = 0;
            p_body5_x = 0; p_body5_y = 0;
            p_body6_x = 0; p_body6_y = 0;
            p_direction = 2'b01; p_length = 4'd2;

            r_head_x = 6'd30; r_head_y = 6'd15;
            r_body0_x = 6'd31; r_body0_y = 6'd15;
            r_body1_x = 0; r_body1_y = 0;
            r_body2_x = 0; r_body2_y = 0;
            r_body3_x = 0; r_body3_y = 0;
            r_body4_x = 0; r_body4_y = 0;
            r_body5_x = 0; r_body5_y = 0;
            r_body6_x = 0; r_body6_y = 0;
            r_direction = 2'b11; r_length = 4'd2;

            food_x = 6'd10; food_y = 6'd10;

            fsm_state = 3'd1; // PLAYING
            info_active = 1'b0;
            info_rgb = 12'h000;

            // Default sprite data: all opaque
            p_head_sprite_data = 12'hF00;
            r_head_sprite_data = 12'h00F;
            food_sprite_data = 12'hFF0;
            obstacle_sprite_data = 12'hF0F;
            victory_sprite_data = 12'hF22;
            gameover_sprite_data = 12'hF00;
        end
    endtask

    initial begin
        $display("=== tb_pixel_renderer_priority ===");
        clk = 0;
        video_active = 1;
        pixel_x = 0; pixel_y = 0;
        init_state;

        #100;

        // -----------------------------------------------
        // T1: Outside active video -> black
        // -----------------------------------------------
        video_active = 0;
        pixel_x = 100; pixel_y = 200;
        check_rgb(4'h0, 4'h0, 4'h0, "T1:inactive");
        video_active = 1;

        // -----------------------------------------------
        // T2: Info bar passthrough
        // -----------------------------------------------
        info_active = 1;
        info_rgb = 12'hABC;
        pixel_x = 100; pixel_y = 50;
        check_rgb(4'hA, 4'hB, 4'hC, "T2:info_bar");
        info_active = 0;

        // -----------------------------------------------
        // T3: Player head sprite (opaque)
        // -----------------------------------------------
        // Player head at tile (2,2). Pixel within that tile: x=32..47, y=106+32=138..153
        pixel_x = 10'd35; pixel_y = 10'd140;
        p_head_sprite_data = 12'hF00; // opaque red
        check_rgb(4'hF, 4'h0, 4'h0, "T3:p_head_opaque");

        // -----------------------------------------------
        // T4: Player head sprite with transparency -> fallthrough to bg
        // -----------------------------------------------
        p_head_sprite_data = 12'h000; // transparent
        check_rgb(4'h1, 4'h1, 4'h1, "T4:p_head_transparent");
        p_head_sprite_data = 12'hF00; // restore

        // -----------------------------------------------
        // T5: Player body -> solid green
        // -----------------------------------------------
        // Body0 at tile (1,2). Pixel: x=16..31, y=138..153
        pixel_x = 10'd20; pixel_y = 10'd140;
        check_rgb(4'h0, 4'hD, 4'h0, "T5:p_body");

        // -----------------------------------------------
        // T6: Food sprite (opaque)
        // -----------------------------------------------
        pixel_x = 10'd163; pixel_y = 10'd266; // tile(10,10): x=160..175, y=106+160=266..281
        food_sprite_data = 12'hFF0;
        check_rgb(4'hF, 4'hF, 4'h0, "T6:food");

        // -----------------------------------------------
        // T7: Obstacle sprite
        // -----------------------------------------------
        // Obstacle at (20,8): x=320..335, y=106+128=234..249
        pixel_x = 10'd325; pixel_y = 10'd238;
        obstacle_sprite_data = 12'hF0F;
        check_rgb(4'hF, 4'h0, 4'hF, "T7:obstacle");

        // -----------------------------------------------
        // T8: Playfield background (empty tile)
        // -----------------------------------------------
        pixel_x = 10'd400; pixel_y = 10'd300;  // some empty tile
        check_rgb(4'h1, 4'h1, 4'h1, "T8:pf_bg");

        // -----------------------------------------------
        // T9: Border
        // -----------------------------------------------
        pixel_x = 10'd0; pixel_y = 10'd106;  // left border
        check_rgb(4'hF, 4'hF, 4'hF, "T9:border");

        // -----------------------------------------------
        // T10: GameOver banner
        // -----------------------------------------------
        fsm_state = 3'd4; // GAME_OVER
        gameover_sprite_data = 12'hF22;
        pixel_x = 10'd200; pixel_y = 10'd280;  // within banner region
        check_rgb(4'hF, 4'h2, 4'h2, "T10:gameover_banner");

        // T10b: GameOver banner transparent pixel -> fallthrough
        gameover_sprite_data = 12'h000;
        check_rgb(4'h1, 4'h1, 4'h1, "T10b:banner_transparent");

        // -----------------------------------------------
        // T11: Lower background
        // -----------------------------------------------
        fsm_state = 3'd1;
        pixel_x = 10'd100; pixel_y = 10'd102;  // between info bar and playfield
        check_rgb(4'h0, 4'h0, 4'h2, "T11:lower_bg");

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
