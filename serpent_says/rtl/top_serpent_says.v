`timescale 1ns / 1ps

module top_serpent_says(
    input  wire CLK100MHZ,
    input  wire CPU_RESETN,

    output wire VGA_HS,
    output wire VGA_VS,
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B
);

wire clk_25mhz;

wire hsync_int;
wire vsync_int;
wire [9:0] pixel_x;
wire [9:0] pixel_y;
wire video_active;

wire [3:0] red_int;
wire [3:0] green_int;
wire [3:0] blue_int;

localparam integer INFO_BAR_HEIGHT      = 100;

localparam integer PLAYFIELD_X_START    = 0;
localparam integer PLAYFIELD_X_END      = 639;
localparam integer PLAYFIELD_Y_START    = 106;
localparam integer PLAYFIELD_Y_END      = 473;

localparam integer TILE_SIZE            = 16;

// Static game scene tile positions
localparam integer SNAKE_HEAD_X         = 5;
localparam integer SNAKE_HEAD_Y         = 5;

localparam integer SNAKE_BODY0_X        = 4;
localparam integer SNAKE_BODY0_Y        = 5;
localparam integer SNAKE_BODY1_X        = 3;
localparam integer SNAKE_BODY1_Y        = 5;
localparam integer SNAKE_BODY2_X        = 2;
localparam integer SNAKE_BODY2_Y        = 5;

localparam integer FOOD_X               = 12;
localparam integer FOOD_Y               = 10;

localparam integer OBS0_X               = 20;
localparam integer OBS0_Y               = 8;
localparam integer OBS1_X               = 20;
localparam integer OBS1_Y               = 9;
localparam integer OBS2_X               = 20;
localparam integer OBS2_Y               = 10;
localparam integer OBS3_X               = 21;
localparam integer OBS3_Y               = 10;
localparam integer OBS4_X               = 22;
localparam integer OBS4_Y               = 10;

wire info_bar_region;
wire playfield_region;
wire playfield_border_region;
wire lower_bg_region;
wire outer_visible_border_region;

wire snake_head_region;
wire snake_body_region;
wire food_region;
wire obstacle_region;

clk_divider u_clk_divider (
    .clk_in   (CLK100MHZ),
    .reset_n  (CPU_RESETN),
    .clk_out  (clk_25mhz)
);

vga_controller u_vga_controller (
    .clk_pix      (clk_25mhz),
    .reset_n      (CPU_RESETN),
    .hsync        (hsync_int),
    .vsync        (vsync_int),
    .pixel_x      (pixel_x),
    .pixel_y      (pixel_y),
    .video_active (video_active)
);

assign info_bar_region =
    video_active && (pixel_y < INFO_BAR_HEIGHT);

assign playfield_region =
    video_active &&
    (pixel_x >= PLAYFIELD_X_START) && (pixel_x <= PLAYFIELD_X_END) &&
    (pixel_y >= PLAYFIELD_Y_START) && (pixel_y <= PLAYFIELD_Y_END);

assign playfield_border_region =
    playfield_region &&
    (
        (pixel_x == PLAYFIELD_X_START) || (pixel_x == PLAYFIELD_X_END) ||
        (pixel_y == PLAYFIELD_Y_START) || (pixel_y == PLAYFIELD_Y_END)
    );

assign lower_bg_region =
    video_active &&
    (pixel_y >= INFO_BAR_HEIGHT) &&
    !playfield_region;

assign outer_visible_border_region =
    video_active &&
    (
        (pixel_x == 10'd0)   || (pixel_x == 10'd639) ||
        (pixel_y == 10'd0)   || (pixel_y == 10'd479)
    );

// Static snake head
assign snake_head_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + SNAKE_HEAD_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (SNAKE_HEAD_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + SNAKE_HEAD_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (SNAKE_HEAD_Y + 1) * TILE_SIZE));

// Static snake body
wire snake_body0_region;
wire snake_body1_region;
wire snake_body2_region;

assign snake_body0_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + SNAKE_BODY0_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (SNAKE_BODY0_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + SNAKE_BODY0_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (SNAKE_BODY0_Y + 1) * TILE_SIZE));

assign snake_body1_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + SNAKE_BODY1_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (SNAKE_BODY1_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + SNAKE_BODY1_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (SNAKE_BODY1_Y + 1) * TILE_SIZE));

assign snake_body2_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + SNAKE_BODY2_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (SNAKE_BODY2_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + SNAKE_BODY2_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (SNAKE_BODY2_Y + 1) * TILE_SIZE));

assign snake_body_region =
    snake_body0_region || snake_body1_region || snake_body2_region;

// Static food
assign food_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + FOOD_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (FOOD_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + FOOD_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (FOOD_Y + 1) * TILE_SIZE));

// Static obstacles
wire obstacle0_region;
wire obstacle1_region;
wire obstacle2_region;
wire obstacle3_region;
wire obstacle4_region;

assign obstacle0_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + OBS0_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (OBS0_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + OBS0_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (OBS0_Y + 1) * TILE_SIZE));

assign obstacle1_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + OBS1_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (OBS1_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + OBS1_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (OBS1_Y + 1) * TILE_SIZE));

assign obstacle2_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + OBS2_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (OBS2_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + OBS2_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (OBS2_Y + 1) * TILE_SIZE));

assign obstacle3_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + OBS3_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (OBS3_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + OBS3_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (OBS3_Y + 1) * TILE_SIZE));

assign obstacle4_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + OBS4_X * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (OBS4_X + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + OBS4_Y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (OBS4_Y + 1) * TILE_SIZE));

assign obstacle_region =
    obstacle0_region || obstacle1_region || obstacle2_region ||
    obstacle3_region || obstacle4_region;

// Colour priority:
// 1. outside active video -> black
// 2. outer visible border -> white
// 3. info bar -> yellow
// 4. playfield border -> white
// 5. snake head -> red
// 6. snake body -> green
// 7. food -> yellow
// 8. obstacles -> magenta
// 9. playfield interior -> dark grey
// 10. lower background -> blue

assign red_int =
    !video_active               ? 4'h0 :
    outer_visible_border_region ? 4'hF :
    info_bar_region             ? 4'hF :
    playfield_border_region     ? 4'hF :
    snake_head_region           ? 4'hF :
    snake_body_region           ? 4'h0 :
    food_region                 ? 4'hF :
    obstacle_region             ? 4'hF :
    playfield_region            ? 4'h1 :
    lower_bg_region             ? 4'h0 :
                                  4'h0;

assign green_int =
    !video_active               ? 4'h0 :
    outer_visible_border_region ? 4'hF :
    info_bar_region             ? 4'hF :
    playfield_border_region     ? 4'hF :
    snake_head_region           ? 4'h0 :
    snake_body_region           ? 4'hF :
    food_region                 ? 4'hF :
    obstacle_region             ? 4'h0 :
    playfield_region            ? 4'h1 :
    lower_bg_region             ? 4'h0 :
                                  4'h0;

assign blue_int =
    !video_active               ? 4'h0 :
    outer_visible_border_region ? 4'hF :
    info_bar_region             ? 4'h0 :
    playfield_border_region     ? 4'hF :
    snake_head_region           ? 4'h0 :
    snake_body_region           ? 4'h0 :
    food_region                 ? 4'h0 :
    obstacle_region             ? 4'hF :
    playfield_region            ? 4'h1 :
    lower_bg_region             ? 4'hF :
                                  4'h0;

assign VGA_HS = hsync_int;
assign VGA_VS = vsync_int;
assign VGA_R  = red_int;
assign VGA_G  = green_int;
assign VGA_B  = blue_int;

endmodule