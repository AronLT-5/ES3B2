`timescale 1ns / 1ps

module top_serpent_says #(
    parameter GAME_TICK_COUNT_MAX = 12_500_000  // 0.5s at 25 MHz
)(
    input  wire CLK100MHZ,
    input  wire CPU_RESETN,
    input  wire BTNL,
    input  wire BTNR,

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

localparam integer ARENA_X_MAX =
    (PLAYFIELD_X_END - PLAYFIELD_X_START + 1) / TILE_SIZE - 1;  // 39
localparam integer ARENA_Y_MAX =
    (PLAYFIELD_Y_END - PLAYFIELD_Y_START + 1) / TILE_SIZE - 1;  // 22

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

// Game state registers
reg [5:0] head_x,  head_y;
reg [5:0] body0_x, body0_y;
reg [5:0] body1_x, body1_y;
reg [5:0] body2_x, body2_y;
reg [1:0] direction;  // 00=up, 01=right, 10=down, 11=left
reg       game_over;
reg [5:0] food_x, food_y;
reg [1:0] food_idx;

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

// --- Game tick counter ---
reg [31:0] tick_counter;
wire game_tick = (tick_counter == GAME_TICK_COUNT_MAX - 1);

always @(posedge clk_25mhz or negedge CPU_RESETN) begin
    if (!CPU_RESETN)
        tick_counter <= 32'd0;
    else if (game_tick)
        tick_counter <= 32'd0;
    else
        tick_counter <= tick_counter + 32'd1;
end

// --- Rising-edge detection for buttons ---
reg btnl_prev, btnr_prev;

always @(posedge clk_25mhz or negedge CPU_RESETN) begin
    if (!CPU_RESETN) begin
        btnl_prev <= 1'b0;
        btnr_prev <= 1'b0;
    end else begin
        btnl_prev <= BTNL;
        btnr_prev <= BTNR;
    end
end

wire btnl_rise = BTNL & ~btnl_prev;
wire btnr_rise = BTNR & ~btnr_prev;

// --- Turn request latches ---
reg turn_left_pending;
reg turn_right_pending;

always @(posedge clk_25mhz or negedge CPU_RESETN) begin
    if (!CPU_RESETN) begin
        turn_left_pending  <= 1'b0;
        turn_right_pending <= 1'b0;
    end else if (game_tick) begin
        turn_left_pending  <= 1'b0;
        turn_right_pending <= 1'b0;
    end else begin
        if (btnl_rise) turn_left_pending  <= 1'b1;
        if (btnr_rise) turn_right_pending <= 1'b1;
    end
end

// --- Next direction (relative turning, BTNL priority) ---
wire [1:0] next_direction = turn_left_pending  ? (direction - 2'd1) :
                            turn_right_pending ? (direction + 2'd1) :
                            direction;

// --- Next head position (unclamped) ---
reg [5:0] next_head_x, next_head_y;

always @(*) begin
    next_head_x = head_x;
    next_head_y = head_y;
    case (next_direction)
        2'b00: next_head_y = head_y - 6'd1;
        2'b01: next_head_x = head_x + 6'd1;
        2'b10: next_head_y = head_y + 6'd1;
        2'b11: next_head_x = head_x - 6'd1;
    endcase
end

// --- Collision detection ---
wire would_hit_wall =
    (next_direction == 2'b00 && head_y == 0) ||
    (next_direction == 2'b01 && head_x == ARENA_X_MAX) ||
    (next_direction == 2'b10 && head_y == ARENA_Y_MAX) ||
    (next_direction == 2'b11 && head_x == 0);

wire would_hit_obstacle =
    (next_head_x == OBS0_X && next_head_y == OBS0_Y) ||
    (next_head_x == OBS1_X && next_head_y == OBS1_Y) ||
    (next_head_x == OBS2_X && next_head_y == OBS2_Y) ||
    (next_head_x == OBS3_X && next_head_y == OBS3_Y) ||
    (next_head_x == OBS4_X && next_head_y == OBS4_Y);

// --- Food collection detection ---
wire ate_food = (next_head_x == food_x) && (next_head_y == food_y);

// --- Game state update ---
always @(posedge clk_25mhz or negedge CPU_RESETN) begin
    if (!CPU_RESETN) begin
        head_x    <= 6'd5;   head_y    <= 6'd5;
        body0_x   <= 6'd4;   body0_y   <= 6'd5;
        body1_x   <= 6'd3;   body1_y   <= 6'd5;
        body2_x   <= 6'd2;   body2_y   <= 6'd5;
        direction <= 2'b01;  // right
        game_over <= 1'b0;
        food_x    <= 6'd12;  food_y    <= 6'd10;
        food_idx  <= 2'd0;
    end else if (game_tick && !game_over) begin
        if (would_hit_wall || would_hit_obstacle) begin
            game_over <= 1'b1;
        end else begin
            direction <= next_direction;
            head_x  <= next_head_x;
            head_y  <= next_head_y;
            body0_x <= head_x;
            body0_y <= head_y;
            body1_x <= body0_x;
            body1_y <= body0_y;
            body2_x <= body1_x;
            body2_y <= body1_y;
            if (ate_food) begin
                case (food_idx)
                    2'd0: begin food_x <= 6'd25; food_y <= 6'd5;  food_idx <= 2'd1; end
                    2'd1: begin food_x <= 6'd8;  food_y <= 6'd15; food_idx <= 2'd2; end
                    2'd2: begin food_x <= 6'd30; food_y <= 6'd3;  food_idx <= 2'd3; end
                    2'd3: begin food_x <= 6'd12; food_y <= 6'd10; food_idx <= 2'd0; end
                endcase
            end
        end
    end
end

// --- Region flags ---
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

assign snake_head_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + head_x * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (head_x + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + head_y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (head_y + 1) * TILE_SIZE));

wire snake_body0_region;
wire snake_body1_region;
wire snake_body2_region;

assign snake_body0_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + body0_x * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (body0_x + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + body0_y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (body0_y + 1) * TILE_SIZE));

assign snake_body1_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + body1_x * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (body1_x + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + body1_y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (body1_y + 1) * TILE_SIZE));

assign snake_body2_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + body2_x * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (body2_x + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + body2_y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (body2_y + 1) * TILE_SIZE));

assign snake_body_region =
    snake_body0_region || snake_body1_region || snake_body2_region;

assign food_region =
    playfield_region &&
    (pixel_x >= (PLAYFIELD_X_START + food_x * TILE_SIZE)) &&
    (pixel_x <  (PLAYFIELD_X_START + (food_x + 1) * TILE_SIZE)) &&
    (pixel_y >= (PLAYFIELD_Y_START + food_y * TILE_SIZE)) &&
    (pixel_y <  (PLAYFIELD_Y_START + (food_y + 1) * TILE_SIZE));

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
    info_bar_region             ? (game_over ? 4'h0 : 4'hF) :
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