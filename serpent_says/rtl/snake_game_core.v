`timescale 1ns / 1ps

module snake_game_core #(
    parameter INITIAL_LIVES     = 3,
    parameter INITIAL_SNAKE_LEN = 2,
    parameter MAX_SNAKE_LEN     = 8,
    parameter ARENA_X_MAX       = 39,
    parameter ARENA_Y_MAX       = 22,
    // Player spawns
    parameter [5:0] P_INIT_HEAD_X  = 6'd5,
    parameter [5:0] P_INIT_HEAD_Y  = 6'd5,
    parameter [5:0] P_INIT_BODY0_X = 6'd4,
    parameter [5:0] P_INIT_BODY0_Y = 6'd5,
    parameter [1:0] P_INIT_DIR     = 2'b01,  // right
    parameter [5:0] P_ALT_HEAD_X   = 6'd5,
    parameter [5:0] P_ALT_HEAD_Y   = 6'd17,
    parameter [5:0] P_ALT_BODY0_X  = 6'd4,
    parameter [5:0] P_ALT_BODY0_Y  = 6'd17,
    // Rival spawns
    parameter [5:0] R_INIT_HEAD_X  = 6'd34,
    parameter [5:0] R_INIT_HEAD_Y  = 6'd17,
    parameter [5:0] R_INIT_BODY0_X = 6'd35,
    parameter [5:0] R_INIT_BODY0_Y = 6'd17,
    parameter [1:0] R_INIT_DIR     = 2'b11,  // left
    parameter [5:0] R_ALT_HEAD_X   = 6'd34,
    parameter [5:0] R_ALT_HEAD_Y   = 6'd5,
    parameter [5:0] R_ALT_BODY0_X  = 6'd35,
    parameter [5:0] R_ALT_BODY0_Y  = 6'd5
)(
    input  wire       clk,
    input  wire       reset_n,
    input  wire       game_tick,
    input  wire       start_btn,
    input  wire       pause_sw,

    // Player turn input (from turn_request_mux, one-cycle events)
    input  wire [1:0] player_turn_req,
    input  wire       player_turn_valid,
    input  wire [1:0] turn_source_in,

    // Rival turn input (combinational from AI)
    input  wire [1:0] rival_turn_req,

    // --- State outputs ---
    output reg  [2:0] fsm_state,

    // Player snake
    output reg  [5:0] p_head_x,  output reg [5:0] p_head_y,
    output reg  [5:0] p_body0_x, output reg [5:0] p_body0_y,
    output reg  [5:0] p_body1_x, output reg [5:0] p_body1_y,
    output reg  [5:0] p_body2_x, output reg [5:0] p_body2_y,
    output reg  [5:0] p_body3_x, output reg [5:0] p_body3_y,
    output reg  [5:0] p_body4_x, output reg [5:0] p_body4_y,
    output reg  [5:0] p_body5_x, output reg [5:0] p_body5_y,
    output reg  [5:0] p_body6_x, output reg [5:0] p_body6_y,
    output reg  [1:0] p_direction,
    output reg  [3:0] p_length,
    output reg  [1:0] p_lives,

    // Rival snake
    output reg  [5:0] r_head_x,  output reg [5:0] r_head_y,
    output reg  [5:0] r_body0_x, output reg [5:0] r_body0_y,
    output reg  [5:0] r_body1_x, output reg [5:0] r_body1_y,
    output reg  [5:0] r_body2_x, output reg [5:0] r_body2_y,
    output reg  [5:0] r_body3_x, output reg [5:0] r_body3_y,
    output reg  [5:0] r_body4_x, output reg [5:0] r_body4_y,
    output reg  [5:0] r_body5_x, output reg [5:0] r_body5_y,
    output reg  [5:0] r_body6_x, output reg [5:0] r_body6_y,
    output reg  [1:0] r_direction,
    output reg  [3:0] r_length,
    output reg  [1:0] r_lives,

    // Shared
    output reg  [5:0] food_x,
    output reg  [5:0] food_y,
    output reg  [1:0] last_turn_source,
    output reg  [1:0] last_player_cmd,

    // Animation
    output wire       anim_p_dying,     // Player is in death animation
    output wire       anim_r_dying,     // Rival is in death animation
    output wire       anim_food_eaten,  // Food was just eaten (1-tick pulse)

    // Debug
    output wire       dbg_p_turn_accepted,
    output wire       dbg_r_dir_changed,
    output wire       dbg_p_collision,
    output wire       dbg_r_collision,
    output wire       dbg_p_ate,
    output wire       dbg_r_ate
);

    // --- FSM state encoding ---
    localparam IDLE       = 3'd0;
    localparam PLAYING    = 3'd1;
    localparam PAUSED     = 3'd2;
    localparam VICTORY    = 3'd3;
    localparam GAME_OVER  = 3'd4;
    localparam RESPAWNING = 3'd5;  // Death animation freeze before respawn

    // Respawn animation timer (~1.5s at 25 MHz)
    localparam RESPAWN_TICKS = 25'd37_500_000;
    reg [24:0] respawn_timer;
    // Which snake(s) died in this respawn cycle
    reg        respawn_p_died;
    reg        respawn_r_died;

    // --- Obstacles (shared definition) ---
    `include "arena_map.vh"

    // --- Food candidates (8) ---
    localparam [5:0] FC0_X = 6'd14, FC0_Y = 6'd10;  // moved from (12,10) to avoid Seg1
    localparam [5:0] FC1_X = 6'd25, FC1_Y = 6'd5;
    localparam [5:0] FC2_X = 6'd8,  FC2_Y = 6'd15;
    localparam [5:0] FC3_X = 6'd30, FC3_Y = 6'd3;
    localparam [5:0] FC4_X = 6'd18, FC4_Y = 6'd18;
    localparam [5:0] FC5_X = 6'd32, FC5_Y = 6'd11;
    localparam [5:0] FC6_X = 6'd6,  FC6_Y = 6'd3;
    localparam [5:0] FC7_X = 6'd28, FC7_Y = 6'd19;

    reg [2:0] food_idx;

    // --- Pending turn latch ---
    reg [1:0] pending_turn;
    reg       pending_valid;
    reg [1:0] pending_source;

    // --- Debug regs (one-tick pulses) ---
    reg dbg_p_turn_r, dbg_r_dir_r, dbg_p_coll_r, dbg_r_coll_r, dbg_p_ate_r, dbg_r_ate_r;
    assign anim_p_dying = (fsm_state == RESPAWNING) && respawn_p_died;
    assign anim_r_dying = (fsm_state == RESPAWNING) && respawn_r_died;
    assign anim_food_eaten = dbg_p_ate_r || dbg_r_ate_r;  // Reuse existing 1-tick eat pulses

    assign dbg_p_turn_accepted = dbg_p_turn_r;
    assign dbg_r_dir_changed   = dbg_r_dir_r;
    assign dbg_p_collision     = dbg_p_coll_r;
    assign dbg_r_collision     = dbg_r_coll_r;
    assign dbg_p_ate           = dbg_p_ate_r;
    assign dbg_r_ate           = dbg_r_ate_r;

    // --- Occupancy check functions ---
    // obstacle_at() provided by arena_map.vh

    // Food candidate lookup
    function [5:0] fc_x;
        input [2:0] idx;
        case (idx)
            3'd0: fc_x = FC0_X;  3'd1: fc_x = FC1_X;
            3'd2: fc_x = FC2_X;  3'd3: fc_x = FC3_X;
            3'd4: fc_x = FC4_X;  3'd5: fc_x = FC5_X;
            3'd6: fc_x = FC6_X;  3'd7: fc_x = FC7_X;
            default: fc_x = FC0_X;
        endcase
    endfunction

    function [5:0] fc_y;
        input [2:0] idx;
        case (idx)
            3'd0: fc_y = FC0_Y;  3'd1: fc_y = FC1_Y;
            3'd2: fc_y = FC2_Y;  3'd3: fc_y = FC3_Y;
            3'd4: fc_y = FC4_Y;  3'd5: fc_y = FC5_Y;
            3'd6: fc_y = FC6_Y;  3'd7: fc_y = FC7_Y;
            default: fc_y = FC0_Y;
        endcase
    endfunction

    // --- Movement tick logic (combinational) ---

    // Step 1-2: Apply turns
    wire [1:0] next_p_dir = pending_valid ?
        (pending_turn == 2'b01 ? (p_direction - 2'd1) :
         pending_turn == 2'b10 ? (p_direction + 2'd1) :
                                  p_direction) :
        p_direction;

    wire [1:0] next_r_dir = rival_turn_req;

    // Step 3: Compute next heads
    reg [5:0] next_p_hx, next_p_hy, next_r_hx, next_r_hy;

    always @(*) begin
        next_p_hx = p_head_x;  next_p_hy = p_head_y;
        case (next_p_dir)
            2'b00: next_p_hy = p_head_y - 6'd1;
            2'b01: next_p_hx = p_head_x + 6'd1;
            2'b10: next_p_hy = p_head_y + 6'd1;
            2'b11: next_p_hx = p_head_x - 6'd1;
        endcase
        next_r_hx = r_head_x;  next_r_hy = r_head_y;
        case (next_r_dir)
            2'b00: next_r_hy = r_head_y - 6'd1;
            2'b01: next_r_hx = r_head_x + 6'd1;
            2'b10: next_r_hy = r_head_y + 6'd1;
            2'b11: next_r_hx = r_head_x - 6'd1;
        endcase
    end

    // Step 4: Collision detection

    // Wall collision
    wire p_hit_wall = (next_p_dir == 2'b00 && p_head_y == 0) ||
                      (next_p_dir == 2'b01 && p_head_x == ARENA_X_MAX) ||
                      (next_p_dir == 2'b10 && p_head_y == ARENA_Y_MAX) ||
                      (next_p_dir == 2'b11 && p_head_x == 0);

    wire r_hit_wall = (next_r_dir == 2'b00 && r_head_y == 0) ||
                      (next_r_dir == 2'b01 && r_head_x == ARENA_X_MAX) ||
                      (next_r_dir == 2'b10 && r_head_y == ARENA_Y_MAX) ||
                      (next_r_dir == 2'b11 && r_head_x == 0);

    // Obstacle collision
    wire p_hit_obs = obstacle_at(next_p_hx, next_p_hy);
    wire r_hit_obs = obstacle_at(next_r_hx, next_r_hy);

    // Tail position helpers
    function [5:0] tail_x_fn;
        input [5:0] b0x, b1x, b2x, b3x, b4x, b5x, b6x;
        input [3:0] len;
        case (len)
            4'd2: tail_x_fn = b0x;
            4'd3: tail_x_fn = b1x;
            4'd4: tail_x_fn = b2x;
            4'd5: tail_x_fn = b3x;
            4'd6: tail_x_fn = b4x;
            4'd7: tail_x_fn = b5x;
            4'd8: tail_x_fn = b6x;
            default: tail_x_fn = b0x;
        endcase
    endfunction

    function [5:0] tail_y_fn;
        input [5:0] b0y, b1y, b2y, b3y, b4y, b5y, b6y;
        input [3:0] len;
        case (len)
            4'd2: tail_y_fn = b0y;
            4'd3: tail_y_fn = b1y;
            4'd4: tail_y_fn = b2y;
            4'd5: tail_y_fn = b3y;
            4'd6: tail_y_fn = b4y;
            4'd7: tail_y_fn = b5y;
            4'd8: tail_y_fn = b6y;
            default: tail_y_fn = b0y;
        endcase
    endfunction

    wire [5:0] p_tail_x = tail_x_fn(p_body0_x, p_body1_x, p_body2_x, p_body3_x, p_body4_x, p_body5_x, p_body6_x, p_length);
    wire [5:0] p_tail_y = tail_y_fn(p_body0_y, p_body1_y, p_body2_y, p_body3_y, p_body4_y, p_body5_y, p_body6_y, p_length);
    wire [5:0] r_tail_x = tail_x_fn(r_body0_x, r_body1_x, r_body2_x, r_body3_x, r_body4_x, r_body5_x, r_body6_x, r_length);
    wire [5:0] r_tail_y = tail_y_fn(r_body0_y, r_body1_y, r_body2_y, r_body3_y, r_body4_y, r_body5_y, r_body6_y, r_length);

    // Self-body collision with tail-vacate
    function body_hit;
        input [5:0] tx, ty;
        input [5:0] b0x, b0y, b1x, b1y, b2x, b2y, b3x, b3y, b4x, b4y, b5x, b5y, b6x, b6y;
        input [3:0] len;
        body_hit =
            (tx == b0x && ty == b0y) ||
            (len > 4'd2 && tx == b1x && ty == b1y) ||
            (len > 4'd3 && tx == b2x && ty == b2y) ||
            (len > 4'd4 && tx == b3x && ty == b3y) ||
            (len > 4'd5 && tx == b4x && ty == b4y) ||
            (len > 4'd6 && tx == b5x && ty == b5y) ||
            (len > 4'd7 && tx == b6x && ty == b6y);
    endfunction

    // Food detection (pre-collision for reference, but food only awarded to non-colliding snakes)
    wire p_on_food = (next_p_hx == food_x) && (next_p_hy == food_y);
    wire r_on_food = (next_r_hx == food_x) && (next_r_hy == food_y);

    // Player self-collision
    wire p_self_hit_raw = body_hit(next_p_hx, next_p_hy,
        p_body0_x, p_body0_y, p_body1_x, p_body1_y, p_body2_x, p_body2_y,
        p_body3_x, p_body3_y, p_body4_x, p_body4_y, p_body5_x, p_body5_y,
        p_body6_x, p_body6_y, p_length);
    wire p_at_own_tail = (next_p_hx == p_tail_x) && (next_p_hy == p_tail_y);
    wire p_self_hit = p_self_hit_raw && (p_on_food || !p_at_own_tail);

    // Rival self-collision
    wire r_self_hit_raw = body_hit(next_r_hx, next_r_hy,
        r_body0_x, r_body0_y, r_body1_x, r_body1_y, r_body2_x, r_body2_y,
        r_body3_x, r_body3_y, r_body4_x, r_body4_y, r_body5_x, r_body5_y,
        r_body6_x, r_body6_y, r_length);
    wire r_at_own_tail = (next_r_hx == r_tail_x) && (next_r_hy == r_tail_y);
    wire r_self_hit = r_self_hit_raw && (r_on_food || !r_at_own_tail);

    // Player into rival body (with rival tail-vacate)
    wire p_hit_r_body_raw = body_hit(next_p_hx, next_p_hy,
        r_body0_x, r_body0_y, r_body1_x, r_body1_y, r_body2_x, r_body2_y,
        r_body3_x, r_body3_y, r_body4_x, r_body4_y, r_body5_x, r_body5_y,
        r_body6_x, r_body6_y, r_length);
    wire p_at_r_tail = (next_p_hx == r_tail_x) && (next_p_hy == r_tail_y);
    wire p_hit_r_body = p_hit_r_body_raw && (r_on_food || !p_at_r_tail);

    // Rival into player body (with player tail-vacate)
    wire r_hit_p_body_raw = body_hit(next_r_hx, next_r_hy,
        p_body0_x, p_body0_y, p_body1_x, p_body1_y, p_body2_x, p_body2_y,
        p_body3_x, p_body3_y, p_body4_x, p_body4_y, p_body5_x, p_body5_y,
        p_body6_x, p_body6_y, p_length);
    wire r_at_p_tail = (next_r_hx == p_tail_x) && (next_r_hy == p_tail_y);
    wire r_hit_p_body = r_hit_p_body_raw && (p_on_food || !r_at_p_tail);

    // Head-to-head: both next heads land on same tile
    wire head_to_head = (next_p_hx == next_r_hx) && (next_p_hy == next_r_hy);

    // Head-swap: each moves into the other's current head tile
    wire head_swap = (next_p_hx == r_head_x) && (next_p_hy == r_head_y) &&
                     (next_r_hx == p_head_x) && (next_r_hy == p_head_y);

    // Head-into-head: one snake moves into the other's current head tile
    // (the vacating head becomes body0, so this IS a body collision)
    wire p_into_r_head = (next_p_hx == r_head_x) && (next_p_hy == r_head_y);
    wire r_into_p_head = (next_r_hx == p_head_x) && (next_r_hy == p_head_y);

    // Aggregate collision flags
    wire p_collided = p_hit_wall || p_hit_obs || p_self_hit || p_hit_r_body ||
                      head_to_head || head_swap || p_into_r_head;
    wire r_collided = r_hit_wall || r_hit_obs || r_self_hit || r_hit_p_body ||
                      head_to_head || head_swap || r_into_p_head;

    // Step 5: Food resolution (only non-colliding snakes eat)
    wire p_eats = p_on_food && !p_collided && !head_to_head;
    wire r_eats = r_on_food && !r_collided && !head_to_head;

    // --- Food relocation logic ---
    // Check if a tile is occupied by either snake post-move (for food placement)
    function post_move_occupied;
        input [5:0] tx, ty;
        // Check player snake post-move position
        post_move_occupied =
            (tx == next_p_hx && ty == next_p_hy) ||
            (tx == p_head_x  && ty == p_head_y)  ||  // becomes body0
            (tx == p_body0_x && ty == p_body0_y) ||
            (p_length > 4'd2 && tx == p_body1_x && ty == p_body1_y) ||
            (p_length > 4'd3 && tx == p_body2_x && ty == p_body2_y) ||
            (p_length > 4'd4 && tx == p_body3_x && ty == p_body3_y) ||
            (p_length > 4'd5 && tx == p_body4_x && ty == p_body4_y) ||
            (p_length > 4'd6 && tx == p_body5_x && ty == p_body5_y) ||
            // Check rival snake post-move position
            (tx == next_r_hx && ty == next_r_hy) ||
            (tx == r_head_x  && ty == r_head_y)  ||
            (tx == r_body0_x && ty == r_body0_y) ||
            (r_length > 4'd2 && tx == r_body1_x && ty == r_body1_y) ||
            (r_length > 4'd3 && tx == r_body2_x && ty == r_body2_y) ||
            (r_length > 4'd4 && tx == r_body3_x && ty == r_body3_y) ||
            (r_length > 4'd5 && tx == r_body4_x && ty == r_body4_y) ||
            (r_length > 4'd6 && tx == r_body5_x && ty == r_body5_y);
    endfunction

    function food_cand_safe;
        input [2:0] idx;
        food_cand_safe = !obstacle_at(fc_x(idx), fc_y(idx)) &&
                         !post_move_occupied(fc_x(idx), fc_y(idx));
    endfunction

    wire [2:0] ct1 = food_idx + 3'd1;
    wire [2:0] ct2 = food_idx + 3'd2;
    wire [2:0] ct3 = food_idx + 3'd3;
    wire [2:0] ct4 = food_idx + 3'd4;
    wire [2:0] ct5 = food_idx + 3'd5;
    wire [2:0] ct6 = food_idx + 3'd6;
    wire [2:0] ct7 = food_idx + 3'd7;

    wire [2:0] next_food_idx =
        food_cand_safe(ct1) ? ct1 :
        food_cand_safe(ct2) ? ct2 :
        food_cand_safe(ct3) ? ct3 :
        food_cand_safe(ct4) ? ct4 :
        food_cand_safe(ct5) ? ct5 :
        food_cand_safe(ct6) ? ct6 :
        food_cand_safe(ct7) ? ct7 :
                              ct1;  // fallback

    wire [5:0] next_food_x = fc_x(next_food_idx);
    wire [5:0] next_food_y = fc_y(next_food_idx);

    // --- Respawn helpers ---
    // Check if a spawn position is safe (not occupied by the other surviving snake)
    function spawn_occupied;
        input [5:0] hx, hy, b0x, b0y;
        input [5:0] oh_x, oh_y;  // other snake head
        input [5:0] ob0x, ob0y, ob1x, ob1y, ob2x, ob2y, ob3x, ob3y, ob4x, ob4y, ob5x, ob5y, ob6x, ob6y;
        input [3:0] olen;
        spawn_occupied =
            (hx == oh_x && hy == oh_y) ||
            (b0x == oh_x && b0y == oh_y) ||
            body_hit(hx, hy, ob0x, ob0y, ob1x, ob1y, ob2x, ob2y, ob3x, ob3y, ob4x, ob4y, ob5x, ob5y, ob6x, ob6y, olen) ||
            body_hit(b0x, b0y, ob0x, ob0y, ob1x, ob1y, ob2x, ob2y, ob3x, ob3y, ob4x, ob4y, ob5x, ob5y, ob6x, ob6y, olen);
    endfunction

    // --- Main state machine ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            fsm_state <= IDLE;
            // Player init
            p_head_x <= P_INIT_HEAD_X;  p_head_y <= P_INIT_HEAD_Y;
            p_body0_x <= P_INIT_BODY0_X; p_body0_y <= P_INIT_BODY0_Y;
            p_body1_x <= 6'd0; p_body1_y <= 6'd0;
            p_body2_x <= 6'd0; p_body2_y <= 6'd0;
            p_body3_x <= 6'd0; p_body3_y <= 6'd0;
            p_body4_x <= 6'd0; p_body4_y <= 6'd0;
            p_body5_x <= 6'd0; p_body5_y <= 6'd0;
            p_body6_x <= 6'd0; p_body6_y <= 6'd0;
            p_direction <= P_INIT_DIR;
            p_length <= INITIAL_SNAKE_LEN;
            p_lives <= INITIAL_LIVES;
            // Rival init
            r_head_x <= R_INIT_HEAD_X;  r_head_y <= R_INIT_HEAD_Y;
            r_body0_x <= R_INIT_BODY0_X; r_body0_y <= R_INIT_BODY0_Y;
            r_body1_x <= 6'd0; r_body1_y <= 6'd0;
            r_body2_x <= 6'd0; r_body2_y <= 6'd0;
            r_body3_x <= 6'd0; r_body3_y <= 6'd0;
            r_body4_x <= 6'd0; r_body4_y <= 6'd0;
            r_body5_x <= 6'd0; r_body5_y <= 6'd0;
            r_body6_x <= 6'd0; r_body6_y <= 6'd0;
            r_direction <= R_INIT_DIR;
            r_length <= INITIAL_SNAKE_LEN;
            r_lives <= INITIAL_LIVES;
            // Shared
            food_x <= FC0_X; food_y <= FC0_Y;
            food_idx <= 3'd0;
            last_turn_source <= 2'b00;
            last_player_cmd <= 2'b00;
            // Latch
            pending_turn <= 2'b00;
            pending_valid <= 1'b0;
            pending_source <= 2'b00;
            // Animation
            respawn_timer  <= 25'd0;
            respawn_p_died <= 1'b0;
            respawn_r_died <= 1'b0;
            // Debug
            dbg_p_turn_r <= 1'b0;  dbg_r_dir_r <= 1'b0;
            dbg_p_coll_r <= 1'b0;  dbg_r_coll_r <= 1'b0;
            dbg_p_ate_r <= 1'b0;   dbg_r_ate_r <= 1'b0;
        end else begin
            // Default: clear debug pulses
            dbg_p_turn_r <= 1'b0;  dbg_r_dir_r <= 1'b0;
            dbg_p_coll_r <= 1'b0;  dbg_r_coll_r <= 1'b0;
            dbg_p_ate_r <= 1'b0;   dbg_r_ate_r <= 1'b0;

            // Turn latching: latch one turn between ticks
            if (player_turn_valid && !pending_valid && fsm_state == PLAYING) begin
                pending_turn   <= player_turn_req;
                pending_valid  <= 1'b1;
                pending_source <= turn_source_in;
            end

            case (fsm_state)
                IDLE: begin
                    if (start_btn) begin
                        fsm_state <= PLAYING;
                        // Full game init
                        p_head_x <= P_INIT_HEAD_X;  p_head_y <= P_INIT_HEAD_Y;
                        p_body0_x <= P_INIT_BODY0_X; p_body0_y <= P_INIT_BODY0_Y;
                        p_body1_x <= 6'd0; p_body1_y <= 6'd0;
                        p_body2_x <= 6'd0; p_body2_y <= 6'd0;
                        p_body3_x <= 6'd0; p_body3_y <= 6'd0;
                        p_body4_x <= 6'd0; p_body4_y <= 6'd0;
                        p_body5_x <= 6'd0; p_body5_y <= 6'd0;
                        p_body6_x <= 6'd0; p_body6_y <= 6'd0;
                        p_direction <= P_INIT_DIR;
                        p_length <= INITIAL_SNAKE_LEN;
                        p_lives <= INITIAL_LIVES;
                        r_head_x <= R_INIT_HEAD_X;  r_head_y <= R_INIT_HEAD_Y;
                        r_body0_x <= R_INIT_BODY0_X; r_body0_y <= R_INIT_BODY0_Y;
                        r_body1_x <= 6'd0; r_body1_y <= 6'd0;
                        r_body2_x <= 6'd0; r_body2_y <= 6'd0;
                        r_body3_x <= 6'd0; r_body3_y <= 6'd0;
                        r_body4_x <= 6'd0; r_body4_y <= 6'd0;
                        r_body5_x <= 6'd0; r_body5_y <= 6'd0;
                        r_body6_x <= 6'd0; r_body6_y <= 6'd0;
                        r_direction <= R_INIT_DIR;
                        r_length <= INITIAL_SNAKE_LEN;
                        r_lives <= INITIAL_LIVES;
                        food_x <= FC0_X; food_y <= FC0_Y;
                        food_idx <= 3'd0;
                        pending_valid <= 1'b0;
                        last_player_cmd <= 2'b00;
                        last_turn_source <= 2'b00;
                    end
                end

                PLAYING: begin
                    // Pause check
                    if (pause_sw) begin
                        fsm_state <= PAUSED;
                    end else if (start_btn) begin
                        // Restart from PLAYING (go back to IDLE->PLAYING)
                        fsm_state <= IDLE;
                    end else if (game_tick) begin
                        // --- MOVEMENT TICK ---
                        dbg_p_turn_r <= pending_valid;
                        dbg_r_dir_r  <= (next_r_dir != r_direction);
                        dbg_p_coll_r <= p_collided;
                        dbg_r_coll_r <= r_collided;
                        dbg_p_ate_r  <= p_eats;
                        dbg_r_ate_r  <= r_eats;

                        // Record last command
                        if (pending_valid) begin
                            last_player_cmd  <= pending_turn;
                            last_turn_source <= pending_source;
                        end

                        // Clear pending turn
                        pending_valid <= 1'b0;

                        // --- Resolve collisions, food, lives, movement ---
                        // Player collision
                        if (p_collided) begin
                            if (p_lives <= 2'd1)
                                p_lives <= 2'd0;
                            else
                                p_lives <= p_lives - 2'd1;
                            // Don't respawn yet — RESPAWNING state handles it
                        end else begin
                            // Normal player movement
                            p_direction <= next_p_dir;
                            p_head_x <= next_p_hx;  p_head_y <= next_p_hy;
                            p_body0_x <= p_head_x;   p_body0_y <= p_head_y;
                            p_body1_x <= p_body0_x;  p_body1_y <= p_body0_y;
                            p_body2_x <= p_body1_x;  p_body2_y <= p_body1_y;
                            p_body3_x <= p_body2_x;  p_body3_y <= p_body2_y;
                            p_body4_x <= p_body3_x;  p_body4_y <= p_body3_y;
                            p_body5_x <= p_body4_x;  p_body5_y <= p_body4_y;
                            p_body6_x <= p_body5_x;  p_body6_y <= p_body5_y;
                            if (p_eats && p_length < MAX_SNAKE_LEN)
                                p_length <= p_length + 4'd1;
                        end

                        // Rival collision
                        if (r_collided) begin
                            if (r_lives <= 2'd1)
                                r_lives <= 2'd0;
                            else
                                r_lives <= r_lives - 2'd1;
                            // Don't respawn yet — RESPAWNING state handles it
                        end else begin
                            // Normal rival movement
                            r_direction <= next_r_dir;
                            r_head_x <= next_r_hx;  r_head_y <= next_r_hy;
                            r_body0_x <= r_head_x;   r_body0_y <= r_head_y;
                            r_body1_x <= r_body0_x;  r_body1_y <= r_body0_y;
                            r_body2_x <= r_body1_x;  r_body2_y <= r_body1_y;
                            r_body3_x <= r_body2_x;  r_body3_y <= r_body2_y;
                            r_body4_x <= r_body3_x;  r_body4_y <= r_body3_y;
                            r_body5_x <= r_body4_x;  r_body5_y <= r_body4_y;
                            r_body6_x <= r_body5_x;  r_body6_y <= r_body5_y;
                            if (r_eats && r_length < MAX_SNAKE_LEN)
                                r_length <= r_length + 4'd1;
                        end

                        // Food relocation if eaten
                        if (p_eats || r_eats) begin
                            food_x   <= next_food_x;
                            food_y   <= next_food_y;
                            food_idx <= next_food_idx;
                        end

                        // --- Terminal state resolution ---
                        // GAME_OVER wins over VICTORY if simultaneous
                        if (p_collided && p_lives <= 2'd1) begin
                            fsm_state <= GAME_OVER;
                        end else if (r_collided && r_lives <= 2'd1) begin
                            fsm_state <= VICTORY;
                        end else if (p_eats && (p_length + 4'd1 >= MAX_SNAKE_LEN)) begin
                            fsm_state <= VICTORY;
                        end else if (r_eats && (r_length + 4'd1 >= MAX_SNAKE_LEN)) begin
                            fsm_state <= GAME_OVER;
                        end else if (p_collided || r_collided) begin
                            // Non-terminal collision: freeze for death animation
                            fsm_state      <= RESPAWNING;
                            respawn_timer  <= RESPAWN_TICKS;
                            respawn_p_died <= p_collided;
                            respawn_r_died <= r_collided;
                        end
                    end
                end

                PAUSED: begin
                    if (!pause_sw)
                        fsm_state <= PLAYING;
                    if (start_btn)
                        fsm_state <= IDLE;
                end

                RESPAWNING: begin
                    // Death animation freeze — timer counts down, then respawn
                    if (respawn_timer > 0) begin
                        respawn_timer <= respawn_timer - 25'd1;
                    end else begin
                        // Timer expired: respawn the dead snake(s) and resume
                        if (respawn_p_died) begin
                            if (!spawn_occupied(P_INIT_HEAD_X, P_INIT_HEAD_Y, P_INIT_BODY0_X, P_INIT_BODY0_Y,
                                    r_head_x, r_head_y,
                                    r_body0_x, r_body0_y, r_body1_x, r_body1_y, r_body2_x, r_body2_y,
                                    r_body3_x, r_body3_y, r_body4_x, r_body4_y, r_body5_x, r_body5_y,
                                    r_body6_x, r_body6_y, r_length)) begin
                                p_head_x <= P_INIT_HEAD_X;  p_head_y <= P_INIT_HEAD_Y;
                                p_body0_x <= P_INIT_BODY0_X; p_body0_y <= P_INIT_BODY0_Y;
                            end else begin
                                p_head_x <= P_ALT_HEAD_X;  p_head_y <= P_ALT_HEAD_Y;
                                p_body0_x <= P_ALT_BODY0_X; p_body0_y <= P_ALT_BODY0_Y;
                            end
                            p_body1_x <= 6'd0; p_body1_y <= 6'd0;
                            p_body2_x <= 6'd0; p_body2_y <= 6'd0;
                            p_body3_x <= 6'd0; p_body3_y <= 6'd0;
                            p_body4_x <= 6'd0; p_body4_y <= 6'd0;
                            p_body5_x <= 6'd0; p_body5_y <= 6'd0;
                            p_body6_x <= 6'd0; p_body6_y <= 6'd0;
                            p_direction <= P_INIT_DIR;
                            p_length <= INITIAL_SNAKE_LEN;
                        end
                        if (respawn_r_died) begin
                            if (!spawn_occupied(R_INIT_HEAD_X, R_INIT_HEAD_Y, R_INIT_BODY0_X, R_INIT_BODY0_Y,
                                    p_head_x, p_head_y,
                                    p_body0_x, p_body0_y, p_body1_x, p_body1_y, p_body2_x, p_body2_y,
                                    p_body3_x, p_body3_y, p_body4_x, p_body4_y, p_body5_x, p_body5_y,
                                    p_body6_x, p_body6_y, p_length)) begin
                                r_head_x <= R_INIT_HEAD_X;  r_head_y <= R_INIT_HEAD_Y;
                                r_body0_x <= R_INIT_BODY0_X; r_body0_y <= R_INIT_BODY0_Y;
                            end else begin
                                r_head_x <= R_ALT_HEAD_X;  r_head_y <= R_ALT_HEAD_Y;
                                r_body0_x <= R_ALT_BODY0_X; r_body0_y <= R_ALT_BODY0_Y;
                            end
                            r_body1_x <= 6'd0; r_body1_y <= 6'd0;
                            r_body2_x <= 6'd0; r_body2_y <= 6'd0;
                            r_body3_x <= 6'd0; r_body3_y <= 6'd0;
                            r_body4_x <= 6'd0; r_body4_y <= 6'd0;
                            r_body5_x <= 6'd0; r_body5_y <= 6'd0;
                            r_body6_x <= 6'd0; r_body6_y <= 6'd0;
                            r_direction <= R_INIT_DIR;
                            r_length <= INITIAL_SNAKE_LEN;
                        end
                        respawn_p_died <= 1'b0;
                        respawn_r_died <= 1'b0;
                        fsm_state <= PLAYING;
                    end
                    // Allow restart during death animation
                    if (start_btn)
                        fsm_state <= IDLE;
                end

                VICTORY, GAME_OVER: begin
                    if (start_btn)
                        fsm_state <= IDLE;
                end

                default: fsm_state <= IDLE;
            endcase
        end
    end

endmodule
