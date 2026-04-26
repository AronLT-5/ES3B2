`timescale 1ns / 1ps

// Sprite-based pixel renderer with animation effects:
//   - Death flash (dying snake blinks white/red during RESPAWNING)
//   - Screen shake (playfield Y-offset wobbles during RESPAWNING)
//   - Food pickup flash (food tile glows gold for ~0.2s after eaten)
//   - Snake body gradient (segments darken toward the tail)
// Terminal/title states (TITLE_SCREEN / VICTORY / GAME_OVER) render
// solid black behind their respective sprite, with the info bar still
// visible at y=0..99.

module pixel_renderer #(
    parameter PLAYFIELD_Y_START = 100,   // info bar reserves y=0..99; playfield starts immediately below
    parameter PLAYFIELD_Y_END   = 467,   // 23 tiles * 16 = 368 px -> ends at 100 + 368 - 1
    parameter TILE_SIZE         = 16,
    parameter ARENA_X_MAX       = 39,
    parameter ARENA_Y_MAX       = 22
)(
    input  wire        clk,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        video_active,

    // Game state
    input  wire [2:0]  fsm_state,

    // Animation signals
    input  wire        anim_p_dying,
    input  wire        anim_r_dying,
    input  wire        anim_food_eaten,

    // Player snake
    input  wire [5:0]  p_head_x,  input wire [5:0] p_head_y,
    input  wire [5:0]  p_body0_x, input wire [5:0] p_body0_y,
    input  wire [5:0]  p_body1_x, input wire [5:0] p_body1_y,
    input  wire [5:0]  p_body2_x, input wire [5:0] p_body2_y,
    input  wire [5:0]  p_body3_x, input wire [5:0] p_body3_y,
    input  wire [5:0]  p_body4_x, input wire [5:0] p_body4_y,
    input  wire [5:0]  p_body5_x, input wire [5:0] p_body5_y,
    input  wire [5:0]  p_body6_x, input wire [5:0] p_body6_y,
    input  wire [1:0]  p_direction,
    input  wire [3:0]  p_length,

    // Rival snake
    input  wire [5:0]  r_head_x,  input wire [5:0] r_head_y,
    input  wire [5:0]  r_body0_x, input wire [5:0] r_body0_y,
    input  wire [5:0]  r_body1_x, input wire [5:0] r_body1_y,
    input  wire [5:0]  r_body2_x, input wire [5:0] r_body2_y,
    input  wire [5:0]  r_body3_x, input wire [5:0] r_body3_y,
    input  wire [5:0]  r_body4_x, input wire [5:0] r_body4_y,
    input  wire [5:0]  r_body5_x, input wire [5:0] r_body5_y,
    input  wire [5:0]  r_body6_x, input wire [5:0] r_body6_y,
    input  wire [1:0]  r_direction,
    input  wire [3:0]  r_length,

    // Food
    input  wire [5:0]  food_x,
    input  wire [5:0]  food_y,

    // Info bar passthrough
    input  wire        info_active,
    input  wire [11:0] info_rgb,

    // Sprite ROM data interfaces
    input  wire [11:0] p_head_sprite_data,
    output wire [7:0]  p_head_sprite_addr,
    input  wire [11:0] r_head_sprite_data,
    output wire [7:0]  r_head_sprite_addr,
    input  wire [11:0] food_sprite_data,
    output wire [7:0]  food_sprite_addr,
    input  wire [11:0] obstacle_sprite_data,
    output wire [7:0]  obstacle_sprite_addr,

    // Banner ROMs (block RAM, 1-cycle latency)
    input  wire [11:0] victory_sprite_data,
    output wire [13:0] victory_sprite_addr,
    input  wire [11:0] gameover_sprite_data,
    output wire [13:0] gameover_sprite_addr,

    // TitleText ROM (block RAM, 1-cycle latency, 500x73 = 36500 entries)
    input  wire [11:0] titletext_sprite_data,
    output wire [15:0] titletext_sprite_addr,

    // Title splash ROM (block RAM, 1-cycle latency, 480x270 = 129600 entries)
    input  wire [11:0] title_sprite_data,
    output wire [16:0] title_sprite_addr,

    // Grass tile sprite (16x16, palette already muxed by temp_state at the top)
    input  wire [11:0] grass_sprite_data,
    output wire [7:0]  grass_sprite_addr,

    // Temperature background state
    input  wire [1:0]  temp_state,

    // Final output
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);

    // --- Colour theme ---
    localparam [11:0] P_BODY_BASE    = 12'h57F;  // player body blue
    localparam [11:0] R_BODY_BASE    = 12'hF00;  // rival body red
    localparam [11:0] BORDER_COLOR   = 12'hFFF;
    localparam [11:0] PF_BG_COOL     = 12'h124;
    localparam [11:0] PF_BG_NEUTRAL  = 12'h131;
    localparam [11:0] PF_BG_HOT      = 12'h311;
    localparam [11:0] LOWER_BG       = 12'h002;
    localparam [11:0] BLACK          = 12'h000;
    localparam [11:0] DEATH_FLASH_A  = 12'hFFF;
    localparam [11:0] DEATH_FLASH_B  = 12'hF44;
    localparam [11:0] FOOD_FLASH_CLR = 12'hFD0;  // Gold flash on eat

    // FSM states
    localparam IDLE       = 3'd0;
    localparam PLAYING    = 3'd1;
    localparam VICTORY    = 3'd3;
    localparam GAME_OVER  = 3'd4;
    localparam RESPAWNING    = 3'd5;
    localparam TITLE_SCREEN  = 3'd6;

    // --- Obstacles ---
    `include "arena_map.vh"

    // --- Decorative grass tiles ---
    `include "grass_map.vh"

    // ═══════════════════════════════════════════════
    // Animation counter (free-running 25 MHz)
    // ═══════════════════════════════════════════════
    reg [23:0] anim_cnt;
    always @(posedge clk) anim_cnt <= anim_cnt + 24'd1;

    wire blink_fast = anim_cnt[21];   // ~6 Hz (death flash + food flash)

    // ═══════════════════════════════════════════════
    // Food pickup flash timer (~0.2s = 5M ticks)
    // ═══════════════════════════════════════════════
    reg [22:0] food_flash_cnt;
    wire       food_flashing = (food_flash_cnt != 0);

    always @(posedge clk) begin
        if (anim_food_eaten)
            food_flash_cnt <= 23'd5_000_000;
        else if (food_flash_cnt != 0)
            food_flash_cnt <= food_flash_cnt - 23'd1;
    end

    // ═══════════════════════════════════════════════
    // Screen shake during RESPAWNING
    // Offset playfield Y by +/-2 pixels based on fast counter
    // ═══════════════════════════════════════════════
    wire signed [2:0] shake_offset = (fsm_state == RESPAWNING) ?
        (anim_cnt[19] ? 3'sd2 : -3'sd2) : 3'sd0;

    wire [9:0] shaken_pf_y_start = PLAYFIELD_Y_START + {{7{shake_offset[2]}}, shake_offset};
    wire [9:0] shaken_pf_y_end   = PLAYFIELD_Y_END   + {{7{shake_offset[2]}}, shake_offset};

    // ═══════════════════════════════════════════════
    // Temperature-controlled playfield background
    // ═══════════════════════════════════════════════
    wire [11:0] pf_bg_color = (temp_state == 2'b00) ? PF_BG_COOL    :
                              (temp_state == 2'b10) ? PF_BG_HOT     :
                                                      PF_BG_NEUTRAL;

    // ═══════════════════════════════════════════════
    // Region computation (using shaken Y for playfield)
    // ═══════════════════════════════════════════════
    wire in_playfield = video_active &&
                        (pixel_x <= 10'd639) &&
                        (pixel_y >= shaken_pf_y_start) &&
                        (pixel_y <= shaken_pf_y_end);

    wire playfield_border = in_playfield &&
        (pixel_x == 10'd0 || pixel_x == 10'd639 ||
         pixel_y == shaken_pf_y_start || pixel_y == shaken_pf_y_end);

    wire in_lower_bg = video_active &&
                       (pixel_y >= 10'd100) && !in_playfield;

    // ═══════════════════════════════════════════════
    // Tile coordinates (using shaken Y)
    // ═══════════════════════════════════════════════
    wire [9:0] pf_rel_y = pixel_y - shaken_pf_y_start;
    wire [5:0] tile_x = pixel_x[9:4];
    wire [5:0] tile_y = pf_rel_y[9:4];
    wire [3:0] tile_px = pixel_x[3:0];
    wire [3:0] tile_py = pf_rel_y[3:0];

    wire [7:0] tile_sprite_addr = {tile_py, tile_px};

    // ═══════════════════════════════════════════════
    // Entity hit detection
    // ═══════════════════════════════════════════════
    wire hit_p_head = in_playfield && (tile_x == p_head_x) && (tile_y == p_head_y);
    wire hit_r_head = in_playfield && (tile_x == r_head_x) && (tile_y == r_head_y);

    // Player body segments with index tracking for gradient
    wire hit_p_b0 = in_playfield && (tile_x == p_body0_x) && (tile_y == p_body0_y);
    wire hit_p_b1 = in_playfield && (p_length > 4'd2) && (tile_x == p_body1_x) && (tile_y == p_body1_y);
    wire hit_p_b2 = in_playfield && (p_length > 4'd3) && (tile_x == p_body2_x) && (tile_y == p_body2_y);
    wire hit_p_b3 = in_playfield && (p_length > 4'd4) && (tile_x == p_body3_x) && (tile_y == p_body3_y);
    wire hit_p_b4 = in_playfield && (p_length > 4'd5) && (tile_x == p_body4_x) && (tile_y == p_body4_y);
    wire hit_p_b5 = in_playfield && (p_length > 4'd6) && (tile_x == p_body5_x) && (tile_y == p_body5_y);
    wire hit_p_b6 = in_playfield && (p_length > 4'd7) && (tile_x == p_body6_x) && (tile_y == p_body6_y);
    wire hit_p_body = hit_p_b0 || hit_p_b1 || hit_p_b2 || hit_p_b3 || hit_p_b4 || hit_p_b5 || hit_p_b6;

    // Player body segment index (0=closest to head, 6=tail) for gradient
    wire [2:0] p_seg_idx = hit_p_b0 ? 3'd0 :
                           hit_p_b1 ? 3'd1 :
                           hit_p_b2 ? 3'd2 :
                           hit_p_b3 ? 3'd3 :
                           hit_p_b4 ? 3'd4 :
                           hit_p_b5 ? 3'd5 : 3'd6;

    // Rival body segments
    wire hit_r_b0 = in_playfield && (tile_x == r_body0_x) && (tile_y == r_body0_y);
    wire hit_r_b1 = in_playfield && (r_length > 4'd2) && (tile_x == r_body1_x) && (tile_y == r_body1_y);
    wire hit_r_b2 = in_playfield && (r_length > 4'd3) && (tile_x == r_body2_x) && (tile_y == r_body2_y);
    wire hit_r_b3 = in_playfield && (r_length > 4'd4) && (tile_x == r_body3_x) && (tile_y == r_body3_y);
    wire hit_r_b4 = in_playfield && (r_length > 4'd5) && (tile_x == r_body4_x) && (tile_y == r_body4_y);
    wire hit_r_b5 = in_playfield && (r_length > 4'd6) && (tile_x == r_body5_x) && (tile_y == r_body5_y);
    wire hit_r_b6 = in_playfield && (r_length > 4'd7) && (tile_x == r_body6_x) && (tile_y == r_body6_y);
    wire hit_r_body = hit_r_b0 || hit_r_b1 || hit_r_b2 || hit_r_b3 || hit_r_b4 || hit_r_b5 || hit_r_b6;

    wire [2:0] r_seg_idx = hit_r_b0 ? 3'd0 :
                           hit_r_b1 ? 3'd1 :
                           hit_r_b2 ? 3'd2 :
                           hit_r_b3 ? 3'd3 :
                           hit_r_b4 ? 3'd4 :
                           hit_r_b5 ? 3'd5 : 3'd6;

    wire hit_food = in_playfield && (tile_x == food_x) && (tile_y == food_y);
    wire hit_obs = in_playfield && obstacle_at(tile_x, tile_y);

    // ═══════════════════════════════════════════════
    // Body gradient: darken each channel by seg_idx
    // P_BODY_BASE = 12'h57F -> R=5, G=7, B=F
    // Each segment reduces brightness by 1 per channel
    // ═══════════════════════════════════════════════
    wire [3:0] p_grad_r = (P_BODY_BASE[11:8] > p_seg_idx) ? (P_BODY_BASE[11:8] - {1'b0, p_seg_idx}) : 4'd1;
    wire [3:0] p_grad_g = (P_BODY_BASE[7:4]  > p_seg_idx) ? (P_BODY_BASE[7:4]  - {1'b0, p_seg_idx}) : 4'd1;
    wire [3:0] p_grad_b = (P_BODY_BASE[3:0]  > p_seg_idx) ? (P_BODY_BASE[3:0]  - {1'b0, p_seg_idx}) : 4'd1;
    wire [11:0] p_body_grad = {p_grad_r, p_grad_g, p_grad_b};

    wire [3:0] r_grad_r = (R_BODY_BASE[11:8] > r_seg_idx) ? (R_BODY_BASE[11:8] - {1'b0, r_seg_idx}) : 4'd1;
    wire [3:0] r_grad_g = (R_BODY_BASE[7:4]  > r_seg_idx) ? (R_BODY_BASE[7:4]  - {1'b0, r_seg_idx}) : 4'd1;
    wire [3:0] r_grad_b = (R_BODY_BASE[3:0]  > r_seg_idx) ? (R_BODY_BASE[3:0]  - {1'b0, r_seg_idx}) : 4'd1;
    wire [11:0] r_body_grad = {r_grad_r, r_grad_g, r_grad_b};

    // ═══════════════════════════════════════════════
    // Sprite ROM address assignment
    // ═══════════════════════════════════════════════
    assign p_head_sprite_addr   = tile_sprite_addr;
    assign r_head_sprite_addr   = tile_sprite_addr;
    assign food_sprite_addr     = tile_sprite_addr;
    assign obstacle_sprite_addr = tile_sprite_addr;
    assign grass_sprite_addr    = tile_sprite_addr;

    // ═══════════════════════════════════════════════
    // Banner overlay
    // ═══════════════════════════════════════════════
    localparam VIC_X = 164, VIC_Y = 270, VIC_W = 312, VIC_H = 40;
    localparam GO_X  = 136, GO_Y  = 270, GO_W  = 368, GO_H  = 40;

    wire in_victory_banner_comb = (fsm_state == VICTORY) &&
        (pixel_x >= VIC_X) && (pixel_x < VIC_X + VIC_W) &&
        (pixel_y >= VIC_Y) && (pixel_y < VIC_Y + VIC_H);

    wire in_gameover_banner_comb = (fsm_state == GAME_OVER) &&
        (pixel_x >= GO_X) && (pixel_x < GO_X + GO_W) &&
        (pixel_y >= GO_Y) && (pixel_y < GO_Y + GO_H);

    wire [5:0] vic_row = pixel_y - VIC_Y;
    wire [8:0] vic_col = pixel_x - VIC_X;
    wire [13:0] vic_addr = ({8'b0, vic_row} << 8) + ({8'b0, vic_row} << 5) +
                           ({8'b0, vic_row} << 4) + ({8'b0, vic_row} << 3) +
                           {5'b0, vic_col};

    wire [5:0] go_row = pixel_y - GO_Y;
    wire [8:0] go_col = pixel_x - GO_X;
    wire [13:0] go_addr = ({8'b0, go_row} << 8) + ({8'b0, go_row} << 6) +
                          ({8'b0, go_row} << 5) + ({8'b0, go_row} << 4) +
                          {5'b0, go_col};

    assign victory_sprite_addr  = vic_addr;
    assign gameover_sprite_addr = go_addr;

    // ═══════════════════════════════════════════════
    // Title-screen overlay (TITLE_SCREEN state) -- two stacked sprites:
    //   TitleText  (500x73)  at the top of the safe area
    //   Title      (480x270) below it
    // Safe area = y 100..479 (info bar reserves 0..99). Layout:
    //   TitleText:   y 111..183, x 70..569 (centred)
    //   Title:       y 199..468, x 80..559 (centred, 15-px gap above)
    // Both transparent paths fall through to the BLACK title-screen branch.
    // ═══════════════════════════════════════════════
    localparam TT_X = 70, TT_Y = 111, TT_W = 500, TT_H = 73;
    localparam TITLE_X = 80, TITLE_Y = 199, TITLE_W = 480, TITLE_H = 270;

    wire in_titletext_comb = (fsm_state == TITLE_SCREEN) &&
        (pixel_x >= TT_X) && (pixel_x < TT_X + TT_W) &&
        (pixel_y >= TT_Y) && (pixel_y < TT_Y + TT_H);

    wire in_title_comb = (fsm_state == TITLE_SCREEN) &&
        (pixel_x >= TITLE_X) && (pixel_x < TITLE_X + TITLE_W) &&
        (pixel_y >= TITLE_Y) && (pixel_y < TITLE_Y + TITLE_H);

    // TitleText address = row * 500 + col;  500 = 256+128+64+32+16+4
    // tt_row max = 72 -> 7 bits.
    wire [6:0] tt_row = pixel_y - TT_Y;
    wire [8:0] tt_col = pixel_x - TT_X;
    wire [15:0] tt_addr_calc = ({9'b0, tt_row} << 8) +
                                ({9'b0, tt_row} << 7) +
                                ({9'b0, tt_row} << 6) +
                                ({9'b0, tt_row} << 5) +
                                ({9'b0, tt_row} << 4) +
                                ({9'b0, tt_row} << 2) +
                                {7'b0, tt_col};
    assign titletext_sprite_addr = tt_addr_calc;

    // Title address = row * 480 + col;  480 = 256+128+64+32
    // title_row max = 269 -> 9 bits.
    wire [8:0] title_row = pixel_y - TITLE_Y;
    wire [8:0] title_col = pixel_x - TITLE_X;
    wire [16:0] title_addr_calc = ({8'b0, title_row} << 8) +
                                   ({8'b0, title_row} << 7) +
                                   ({8'b0, title_row} << 6) +
                                   ({8'b0, title_row} << 5) +
                                   {8'b0, title_col};
    assign title_sprite_addr = title_addr_calc;

    // ═══════════════════════════════════════════════
    // Delay block-ROM region signals by 1 cycle to match
    // the 1-cycle read latency of block RAM sprite ROMs.
    // Without this, the first pixel at the left edge shows
    // stale data from the previous (out-of-region) address.
    // ═══════════════════════════════════════════════
    reg in_victory_banner, in_gameover_banner;
    reg in_titletext, in_title;
    always @(posedge clk) begin
        in_victory_banner <= in_victory_banner_comb;
        in_gameover_banner <= in_gameover_banner_comb;
        in_titletext <= in_titletext_comb;
        in_title <= in_title_comb;
    end

    // Death flash colors (used during RESPAWNING dying snake blink)
    wire [11:0] death_color = blink_fast ? DEATH_FLASH_A : DEATH_FLASH_B;

    // ═══════════════════════════════════════════════
    // Priority chain
    //
    // The chain is partitioned by FSM state so that terminal screens
    // (TITLE_SCREEN / VICTORY / GAME_OVER) cannot reach any of the
    // playfield-entity, border, or background branches -- they paint
    // solid BLACK behind their respective sprite, with the info bar
    // always visible at y=0..99.
    // ═══════════════════════════════════════════════
    reg [11:0] pixel_rgb;

    always @(*) begin
        if (!video_active) begin
            pixel_rgb = BLACK;

        // Info bar always wins (y=0..99).
        end else if (info_active) begin
            pixel_rgb = info_rgb;

        // ── Title screen: only TitleText + TitleScreen splash + BLACK ──
        end else if (fsm_state == TITLE_SCREEN) begin
            if (in_titletext && titletext_sprite_data != 12'h000)
                pixel_rgb = titletext_sprite_data;
            else if (in_title && title_sprite_data != 12'h000)
                pixel_rgb = title_sprite_data;
            else
                pixel_rgb = BLACK;

        // ── Victory: only the banner sprite over solid BLACK ──
        end else if (fsm_state == VICTORY) begin
            if (in_victory_banner && victory_sprite_data != 12'h000)
                pixel_rgb = victory_sprite_data;
            else
                pixel_rgb = BLACK;

        // ── Game Over: only the banner sprite over solid BLACK ──
        end else if (fsm_state == GAME_OVER) begin
            if (in_gameover_banner && gameover_sprite_data != 12'h000)
                pixel_rgb = gameover_sprite_data;
            else
                pixel_rgb = BLACK;

        // ── Gameplay states (PLAYING / PAUSED / RESPAWNING / IDLE) ──
        end else begin
            if (playfield_border)
                pixel_rgb = BORDER_COLOR;

            // Player head: flash white during death
            else if (hit_p_head && p_head_sprite_data != 12'h000)
                pixel_rgb = anim_p_dying ? (blink_fast ? 12'hFFF : p_head_sprite_data) : p_head_sprite_data;

            // Rival head: flash white during death
            else if (hit_r_head && r_head_sprite_data != 12'h000)
                pixel_rgb = anim_r_dying ? (blink_fast ? 12'hFFF : r_head_sprite_data) : r_head_sprite_data;

            // Player body: gradient + death flash
            else if (hit_p_body)
                pixel_rgb = anim_p_dying ? death_color : p_body_grad;

            // Rival body: gradient + death flash
            else if (hit_r_body)
                pixel_rgb = anim_r_dying ? death_color : r_body_grad;

            // Food: gold flash after eaten, normal sprite otherwise
            else if (hit_food) begin
                if (food_flashing)
                    pixel_rgb = blink_fast ? FOOD_FLASH_CLR : 12'hFA0;
                else if (food_sprite_data != 12'h000)
                    pixel_rgb = food_sprite_data;
                else
                    pixel_rgb = pf_bg_color;
            end

            // Obstacles
            else if (hit_obs && obstacle_sprite_data != 12'h000)
                pixel_rgb = obstacle_sprite_data;

            // Decorative grass tiles
            else if (in_playfield && grass_at(tile_x, tile_y) && grass_sprite_data != 12'h000)
                pixel_rgb = grass_sprite_data;

            // Playfield background (blinks dark red during RESPAWNING)
            else if (in_playfield)
                pixel_rgb = (fsm_state == RESPAWNING && blink_fast) ? 12'h200 : pf_bg_color;

            // Lower margin (y=468..479 after the playfield shift)
            else if (in_lower_bg)
                pixel_rgb = LOWER_BG;

            else
                pixel_rgb = BLACK;
        end
    end

    assign vga_r = pixel_rgb[11:8];
    assign vga_g = pixel_rgb[7:4];
    assign vga_b = pixel_rgb[3:0];

endmodule
