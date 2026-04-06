`timescale 1ns / 1ps

module top_serpent_says #(
    parameter BUTTON_TICK_COUNT_MAX = 12_500_000,
    parameter VOICE_TICK_COUNT_MAX  = 18_750_000,
    parameter INITIAL_LIVES         = 3
)(
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNC,
    input  wire        BTNL,
    input  wire        BTNR,
    input  wire [2:0]  SW,
    input  wire        pdm_data_i,
    output wire        pdm_clk_o,
    output wire        pdm_lrsel_o,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire [12:0] LED,
    output wire        CA,
    output wire        CB,
    output wire        CC,
    output wire        CD,
    output wire        CE,
    output wire        CF,
    output wire        CG,
    output wire        DP,
    output wire [7:0]  AN
);

    // --- Voice stubs ---
    wire [1:0] voice_turn_req  = 2'b00;
    wire       voice_turn_valid = 1'b0;
    assign pdm_clk_o   = 1'b0;
    assign pdm_lrsel_o  = 1'b0;

    // Unused input
    wire _pdm_unused = pdm_data_i;

    // --- Switch synchroniser ---
    reg [2:0] sw_s1, sw_s2;
    always @(posedge clk_25mhz or negedge CPU_RESETN) begin
        if (!CPU_RESETN) begin
            sw_s1 <= 3'b0;  sw_s2 <= 3'b0;
        end else begin
            sw_s1 <= SW;    sw_s2 <= sw_s1;
        end
    end
    wire pause_sw      = sw_s2[0];
    wire debug_mode    = sw_s2[1];
    wire voice_mode_en = sw_s2[2];

    // --- Clock divider (preserved) ---
    wire clk_25mhz;

    clk_divider u_clk_divider (
        .clk_in  (CLK100MHZ),
        .reset_n (CPU_RESETN),
        .clk_out (clk_25mhz)
    );

    // --- VGA controller (preserved) ---
    wire [9:0] pixel_x, pixel_y;
    wire       hsync_int, vsync_int, video_active;

    vga_controller u_vga_controller (
        .clk_pix      (clk_25mhz),
        .reset_n      (CPU_RESETN),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .hsync        (hsync_int),
        .vsync        (vsync_int),
        .video_active (video_active)
    );

    // --- Game state wires (declared early for tick_enable) ---
    wire [2:0]  fsm_state;

    // --- Game tick generator ---
    wire tick_enable = (fsm_state == 3'd1);  // PLAYING only
    wire game_tick;

    game_tick_gen #(
        .BUTTON_TICK_MAX (BUTTON_TICK_COUNT_MAX),
        .VOICE_TICK_MAX  (VOICE_TICK_COUNT_MAX)
    ) u_tick_gen (
        .clk           (clk_25mhz),
        .reset_n       (CPU_RESETN),
        .enable        (tick_enable),
        .voice_mode_en (voice_mode_en),
        .game_tick     (game_tick)
    );

    // --- Button input adapter ---
    wire [1:0] btn_turn_req;
    wire       btn_turn_valid;
    wire       start_btn;

    button_input_adapter u_btn_adapter (
        .clk       (clk_25mhz),
        .reset_n   (CPU_RESETN),
        .btnl_raw  (BTNL),
        .btnr_raw  (BTNR),
        .btnc_raw  (BTNC),
        .turn_req  (btn_turn_req),
        .turn_valid(btn_turn_valid),
        .start_btn (start_btn)
    );

    // --- Turn request mux ---
    wire [1:0] player_turn_req;
    wire       player_turn_valid;
    wire [1:0] turn_source;

    turn_request_mux u_turn_mux (
        .btn_turn_req    (btn_turn_req),
        .btn_turn_valid  (btn_turn_valid),
        .voice_turn_req  (voice_turn_req),
        .voice_turn_valid(voice_turn_valid),
        .player_turn_req (player_turn_req),
        .player_turn_valid(player_turn_valid),
        .turn_source     (turn_source)
    );

    // --- Game state wires (fsm_state declared above for tick_enable) ---
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
    wire [1:0]  last_turn_source;
    wire [1:0]  last_player_cmd;
    wire        dbg_p_turn_accepted, dbg_r_dir_changed;
    wire        dbg_p_collision, dbg_r_collision;
    wire        dbg_p_ate, dbg_r_ate;

    // --- Rival AI ---
    wire [1:0] rival_turn_req;

    rival_ai_simple u_rival_ai (
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

    // --- Snake game core ---
    snake_game_core #(
        .INITIAL_LIVES(INITIAL_LIVES)
    ) u_game_core (
        .clk(clk_25mhz), .reset_n(CPU_RESETN),
        .game_tick(game_tick), .start_btn(start_btn), .pause_sw(pause_sw),
        .player_turn_req(player_turn_req), .player_turn_valid(player_turn_valid),
        .turn_source_in(turn_source),
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

    // --- Sprite ROMs ---
    // Player head (4 directions)
    wire [7:0]  p_head_sprite_addr;
    wire [11:0] p_head_up_data, p_head_right_data, p_head_down_data, p_head_left_data;

    sprite_rom #(.SPRITE_FILE("Snake_head_up.mem"),    .DEPTH(256)) u_p_head_up   (.clk(clk_25mhz), .addr(p_head_sprite_addr), .data(p_head_up_data));
    sprite_rom #(.SPRITE_FILE("Snake_head_right.mem"), .DEPTH(256)) u_p_head_right(.clk(clk_25mhz), .addr(p_head_sprite_addr), .data(p_head_right_data));
    sprite_rom #(.SPRITE_FILE("Snake_head_down.mem"),  .DEPTH(256)) u_p_head_down (.clk(clk_25mhz), .addr(p_head_sprite_addr), .data(p_head_down_data));
    sprite_rom #(.SPRITE_FILE("Snake_head_left.mem"),  .DEPTH(256)) u_p_head_left (.clk(clk_25mhz), .addr(p_head_sprite_addr), .data(p_head_left_data));

    // Direction MUX for player head
    reg [11:0] p_head_sprite_data;
    always @(*) begin
        case (p_direction)
            2'b00: p_head_sprite_data = p_head_up_data;
            2'b01: p_head_sprite_data = p_head_right_data;
            2'b10: p_head_sprite_data = p_head_down_data;
            2'b11: p_head_sprite_data = p_head_left_data;
        endcase
    end

    // Rival head (4 directions)
    wire [7:0]  r_head_sprite_addr;
    wire [11:0] r_head_up_data, r_head_right_data, r_head_down_data, r_head_left_data;

    sprite_rom #(.SPRITE_FILE("Bot_Snake_head_up.mem"),    .DEPTH(256)) u_r_head_up   (.clk(clk_25mhz), .addr(r_head_sprite_addr), .data(r_head_up_data));
    sprite_rom #(.SPRITE_FILE("Bot_Snake_head_right.mem"), .DEPTH(256)) u_r_head_right(.clk(clk_25mhz), .addr(r_head_sprite_addr), .data(r_head_right_data));
    sprite_rom #(.SPRITE_FILE("Bot_Snake_head_down.mem"),  .DEPTH(256)) u_r_head_down (.clk(clk_25mhz), .addr(r_head_sprite_addr), .data(r_head_down_data));
    sprite_rom #(.SPRITE_FILE("Bot_Snake_head_left.mem"),  .DEPTH(256)) u_r_head_left (.clk(clk_25mhz), .addr(r_head_sprite_addr), .data(r_head_left_data));

    reg [11:0] r_head_sprite_data;
    always @(*) begin
        case (r_direction)
            2'b00: r_head_sprite_data = r_head_up_data;
            2'b01: r_head_sprite_data = r_head_right_data;
            2'b10: r_head_sprite_data = r_head_down_data;
            2'b11: r_head_sprite_data = r_head_left_data;
        endcase
    end

    // Food sprite
    wire [7:0]  food_sprite_addr;
    wire [11:0] food_sprite_data;
    sprite_rom #(.SPRITE_FILE("apple.mem"), .DEPTH(256)) u_food_sprite (.clk(clk_25mhz), .addr(food_sprite_addr), .data(food_sprite_data));

    // Obstacle sprite
    wire [7:0]  obstacle_sprite_addr;
    wire [11:0] obstacle_sprite_data;
    sprite_rom #(.SPRITE_FILE("Obstacle.mem"), .DEPTH(256)) u_obs_sprite (.clk(clk_25mhz), .addr(obstacle_sprite_addr), .data(obstacle_sprite_data));

    // Life icon sprite
    wire [7:0]  life_sprite_addr;
    wire [11:0] life_sprite_data;
    sprite_rom #(.SPRITE_FILE("live.mem"), .DEPTH(256)) u_life_sprite (.clk(clk_25mhz), .addr(life_sprite_addr), .data(life_sprite_data));

    // Victory banner (312x40 = 12480, block ROM)
    wire [13:0] victory_sprite_addr;
    wire [11:0] victory_sprite_data;
    sprite_rom #(.SPRITE_FILE("victory.mem"), .DEPTH(12480), .WIDTH(312), .USE_BLOCK_ROM(1))
        u_victory_sprite (.clk(clk_25mhz), .addr(victory_sprite_addr), .data(victory_sprite_data));

    // Game Over banner (368x40 = 14720, block ROM)
    wire [13:0] gameover_sprite_addr;
    wire [11:0] gameover_sprite_data;
    sprite_rom #(.SPRITE_FILE("gameOver.mem"), .DEPTH(14720), .WIDTH(368), .USE_BLOCK_ROM(1))
        u_gameover_sprite (.clk(clk_25mhz), .addr(gameover_sprite_addr), .data(gameover_sprite_data));

    // --- Info bar renderer ---
    wire        info_active;
    wire [11:0] info_rgb;

    info_bar_renderer u_info_bar (
        .clk(clk_25mhz), .reset_n(CPU_RESETN),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .video_active(video_active),
        .fsm_state(fsm_state),
        .p_length(p_length), .p_lives(p_lives),
        .r_length(r_length), .r_lives(r_lives),
        .last_player_cmd(last_player_cmd),
        .last_turn_source(last_turn_source),
        .voice_mode_en(voice_mode_en),
        .life_sprite_addr(life_sprite_addr),
        .life_sprite_data(life_sprite_data),
        .info_active(info_active),
        .info_rgb(info_rgb)
    );

    // --- Pixel renderer ---
    pixel_renderer u_renderer (
        .clk(clk_25mhz),
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
        .vga_r(VGA_R), .vga_g(VGA_G), .vga_b(VGA_B)
    );

    assign VGA_HS = hsync_int;
    assign VGA_VS = vsync_int;

    // --- Seven-segment driver ---
    wire [6:0] seg_out;

    seven_seg_driver u_seven_seg (
        .clk(clk_25mhz), .reset_n(CPU_RESETN),
        .p_length(p_length), .p_lives(p_lives),
        .r_length(r_length), .r_lives(r_lives),
        .seg(seg_out), .dp(DP), .an(AN)
    );

    assign CA = seg_out[0];
    assign CB = seg_out[1];
    assign CC = seg_out[2];
    assign CD = seg_out[3];
    assign CE = seg_out[4];
    assign CF = seg_out[5];
    assign CG = seg_out[6];

    // --- LED status driver ---
    led_status_driver u_led_driver (
        .debug_mode(debug_mode),
        .voice_ready(voice_mode_en),
        .fsm_state(fsm_state),
        .p_lives(p_lives), .r_lives(r_lives),
        .p_direction(p_direction), .r_direction(r_direction),
        .dbg_p_turn_accepted(dbg_p_turn_accepted),
        .dbg_r_dir_changed(dbg_r_dir_changed),
        .dbg_p_collision(dbg_p_collision),
        .dbg_r_collision(dbg_r_collision),
        .dbg_p_ate(dbg_p_ate),
        .dbg_r_ate(dbg_r_ate),
        .led(LED)
    );

endmodule
