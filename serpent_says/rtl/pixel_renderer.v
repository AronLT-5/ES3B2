`timescale 1ns / 1ps

// Sprite-based pixel renderer with deterministic priority chain.
// Consumes sprite ROM data via address/data port pairs.
// Banner ROMs use block RAM with 1-cycle latency (address registered externally).

module pixel_renderer #(
    parameter PLAYFIELD_Y_START = 106,
    parameter PLAYFIELD_Y_END   = 473,
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

    // Sprite ROM data interfaces (active-direction head already muxed)
    input  wire [11:0] p_head_sprite_data,
    output wire [7:0]  p_head_sprite_addr,
    input  wire [11:0] r_head_sprite_data,
    output wire [7:0]  r_head_sprite_addr,
    input  wire [11:0] food_sprite_data,
    output wire [7:0]  food_sprite_addr,
    input  wire [11:0] obstacle_sprite_data,
    output wire [7:0]  obstacle_sprite_addr,

    // Banner ROMs (block RAM, 1-cycle latency: address driven this cycle, data valid next)
    input  wire [11:0] victory_sprite_data,
    output wire [13:0] victory_sprite_addr,
    input  wire [11:0] gameover_sprite_data,
    output wire [13:0] gameover_sprite_addr,

    // Final output
    output wire [3:0]  vga_r,
    output wire [3:0]  vga_g,
    output wire [3:0]  vga_b
);

    // --- Colour theme (editable) ---
    localparam [11:0] P_BODY_COLOR  = 12'h0D0;  // player body green
    localparam [11:0] R_BODY_COLOR  = 12'h44F;  // rival body blue
    localparam [11:0] BORDER_COLOR  = 12'hFFF;  // white
    localparam [11:0] PF_BG_COLOR   = 12'h111;  // dark grey
    localparam [11:0] LOWER_BG      = 12'h002;  // dark blue
    localparam [11:0] BLACK         = 12'h000;

    // FSM states
    localparam VICTORY   = 3'd3;
    localparam GAME_OVER = 3'd4;

    // --- Obstacle positions (duplicated) ---
    localparam [5:0] OBS0_X = 6'd20, OBS0_Y = 6'd8;
    localparam [5:0] OBS1_X = 6'd20, OBS1_Y = 6'd9;
    localparam [5:0] OBS2_X = 6'd20, OBS2_Y = 6'd10;
    localparam [5:0] OBS3_X = 6'd21, OBS3_Y = 6'd10;
    localparam [5:0] OBS4_X = 6'd22, OBS4_Y = 6'd10;

    // --- Region computation ---
    wire in_playfield = video_active &&
                        (pixel_x <= 10'd639) &&
                        (pixel_y >= PLAYFIELD_Y_START) &&
                        (pixel_y <= PLAYFIELD_Y_END);

    wire playfield_border = in_playfield &&
        (pixel_x == 10'd0 || pixel_x == 10'd639 ||
         pixel_y == PLAYFIELD_Y_START || pixel_y == PLAYFIELD_Y_END);

    wire in_lower_bg = video_active &&
                       (pixel_y >= 10'd100) && !in_playfield;

    // --- Tile coordinates ---
    wire [9:0] pf_rel_y = pixel_y - PLAYFIELD_Y_START;
    wire [5:0] tile_x = pixel_x[9:4];                // pixel_x / 16
    wire [5:0] tile_y = pf_rel_y[9:4];               // (pixel_y - 106) / 16
    wire [3:0] tile_px = pixel_x[3:0];               // pixel_x % 16
    wire [3:0] tile_py = pf_rel_y[3:0];              // (pixel_y - 106) % 16

    // Sprite address for 16x16 tiles
    wire [7:0] tile_sprite_addr = {tile_py, tile_px};

    // --- Entity hit detection (tile space) ---
    wire hit_p_head = in_playfield && (tile_x == p_head_x) && (tile_y == p_head_y);
    wire hit_r_head = in_playfield && (tile_x == r_head_x) && (tile_y == r_head_y);

    // Player body segments
    wire hit_p_b0 = in_playfield && (tile_x == p_body0_x) && (tile_y == p_body0_y);
    wire hit_p_b1 = in_playfield && (p_length > 4'd2) && (tile_x == p_body1_x) && (tile_y == p_body1_y);
    wire hit_p_b2 = in_playfield && (p_length > 4'd3) && (tile_x == p_body2_x) && (tile_y == p_body2_y);
    wire hit_p_b3 = in_playfield && (p_length > 4'd4) && (tile_x == p_body3_x) && (tile_y == p_body3_y);
    wire hit_p_b4 = in_playfield && (p_length > 4'd5) && (tile_x == p_body4_x) && (tile_y == p_body4_y);
    wire hit_p_b5 = in_playfield && (p_length > 4'd6) && (tile_x == p_body5_x) && (tile_y == p_body5_y);
    wire hit_p_b6 = in_playfield && (p_length > 4'd7) && (tile_x == p_body6_x) && (tile_y == p_body6_y);
    wire hit_p_body = hit_p_b0 || hit_p_b1 || hit_p_b2 || hit_p_b3 || hit_p_b4 || hit_p_b5 || hit_p_b6;

    // Rival body segments
    wire hit_r_b0 = in_playfield && (tile_x == r_body0_x) && (tile_y == r_body0_y);
    wire hit_r_b1 = in_playfield && (r_length > 4'd2) && (tile_x == r_body1_x) && (tile_y == r_body1_y);
    wire hit_r_b2 = in_playfield && (r_length > 4'd3) && (tile_x == r_body2_x) && (tile_y == r_body2_y);
    wire hit_r_b3 = in_playfield && (r_length > 4'd4) && (tile_x == r_body3_x) && (tile_y == r_body3_y);
    wire hit_r_b4 = in_playfield && (r_length > 4'd5) && (tile_x == r_body4_x) && (tile_y == r_body4_y);
    wire hit_r_b5 = in_playfield && (r_length > 4'd6) && (tile_x == r_body5_x) && (tile_y == r_body5_y);
    wire hit_r_b6 = in_playfield && (r_length > 4'd7) && (tile_x == r_body6_x) && (tile_y == r_body6_y);
    wire hit_r_body = hit_r_b0 || hit_r_b1 || hit_r_b2 || hit_r_b3 || hit_r_b4 || hit_r_b5 || hit_r_b6;

    // Food
    wire hit_food = in_playfield && (tile_x == food_x) && (tile_y == food_y);

    // Obstacles
    wire hit_obs = in_playfield && (
        (tile_x == OBS0_X && tile_y == OBS0_Y) ||
        (tile_x == OBS1_X && tile_y == OBS1_Y) ||
        (tile_x == OBS2_X && tile_y == OBS2_Y) ||
        (tile_x == OBS3_X && tile_y == OBS3_Y) ||
        (tile_x == OBS4_X && tile_y == OBS4_Y));

    // --- Sprite ROM address assignment ---
    assign p_head_sprite_addr   = tile_sprite_addr;
    assign r_head_sprite_addr   = tile_sprite_addr;
    assign food_sprite_addr     = tile_sprite_addr;
    assign obstacle_sprite_addr = tile_sprite_addr;

    // --- Banner overlay ---
    // Victory: 312x40, centered at (164, 270)
    localparam VIC_X = 164, VIC_Y = 270, VIC_W = 312, VIC_H = 40;
    // GameOver: 368x40, centered at (136, 270)
    localparam GO_X  = 136, GO_Y  = 270, GO_W  = 368, GO_H  = 40;

    wire in_victory_banner = (fsm_state == VICTORY) &&
        (pixel_x >= VIC_X) && (pixel_x < VIC_X + VIC_W) &&
        (pixel_y >= VIC_Y) && (pixel_y < VIC_Y + VIC_H);

    wire in_gameover_banner = (fsm_state == GAME_OVER) &&
        (pixel_x >= GO_X) && (pixel_x < GO_X + GO_W) &&
        (pixel_y >= GO_Y) && (pixel_y < GO_Y + GO_H);

    // Banner address: row * WIDTH + col using shift-and-add
    wire [5:0] vic_row = pixel_y - VIC_Y;
    wire [8:0] vic_col = pixel_x - VIC_X;
    // 312 = 256 + 32 + 16 + 8
    wire [13:0] vic_addr = ({8'b0, vic_row} << 8) + ({8'b0, vic_row} << 5) +
                           ({8'b0, vic_row} << 4) + ({8'b0, vic_row} << 3) +
                           {5'b0, vic_col};

    wire [5:0] go_row = pixel_y - GO_Y;
    wire [8:0] go_col = pixel_x - GO_X;
    // 368 = 256 + 64 + 32 + 16
    wire [13:0] go_addr = ({8'b0, go_row} << 8) + ({8'b0, go_row} << 6) +
                          ({8'b0, go_row} << 5) + ({8'b0, go_row} << 4) +
                          {5'b0, go_col};

    assign victory_sprite_addr  = vic_addr;
    assign gameover_sprite_addr = go_addr;

    // --- Priority chain ---
    reg [11:0] pixel_rgb;

    always @(*) begin
        if (!video_active) begin
            pixel_rgb = BLACK;
        end else if (info_active) begin
            pixel_rgb = info_rgb;
        end else if (in_victory_banner && victory_sprite_data != 12'h000) begin
            pixel_rgb = victory_sprite_data;
        end else if (in_gameover_banner && gameover_sprite_data != 12'h000) begin
            pixel_rgb = gameover_sprite_data;
        end else if (playfield_border) begin
            pixel_rgb = BORDER_COLOR;
        end else if (hit_p_head && p_head_sprite_data != 12'h000) begin
            pixel_rgb = p_head_sprite_data;
        end else if (hit_r_head && r_head_sprite_data != 12'h000) begin
            pixel_rgb = r_head_sprite_data;
        end else if (hit_p_body) begin
            pixel_rgb = P_BODY_COLOR;
        end else if (hit_r_body) begin
            pixel_rgb = R_BODY_COLOR;
        end else if (hit_food && food_sprite_data != 12'h000) begin
            pixel_rgb = food_sprite_data;
        end else if (hit_obs && obstacle_sprite_data != 12'h000) begin
            pixel_rgb = obstacle_sprite_data;
        end else if (in_playfield) begin
            pixel_rgb = PF_BG_COLOR;
        end else if (in_lower_bg) begin
            pixel_rgb = LOWER_BG;
        end else begin
            pixel_rgb = BLACK;
        end
    end

    assign vga_r = pixel_rgb[11:8];
    assign vga_g = pixel_rgb[7:4];
    assign vga_b = pixel_rgb[3:0];

endmodule
