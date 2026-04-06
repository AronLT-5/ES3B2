`timescale 1ns / 1ps

// Deterministic food-seeking AI for the rival snake.
// Purely combinational -- sampled by game core on tick edge.
// Examines forward / relative-left / relative-right, never reverses.
// Picks the safe candidate closest to food (Manhattan distance).
// Tie-break: forward > left > right.

module rival_ai_simple #(
    parameter ARENA_X_MAX = 39,
    parameter ARENA_Y_MAX = 22
)(
    // Rival current state
    input  wire [1:0] r_direction,
    input  wire [5:0] r_head_x,
    input  wire [5:0] r_head_y,
    input  wire [5:0] r_body0_x, r_body0_y,
    input  wire [5:0] r_body1_x, r_body1_y,
    input  wire [5:0] r_body2_x, r_body2_y,
    input  wire [5:0] r_body3_x, r_body3_y,
    input  wire [5:0] r_body4_x, r_body4_y,
    input  wire [5:0] r_body5_x, r_body5_y,
    input  wire [5:0] r_body6_x, r_body6_y,
    input  wire [3:0] r_length,

    // Player state (avoid crashing into)
    input  wire [5:0] p_head_x,  p_head_y,
    input  wire [5:0] p_body0_x, p_body0_y,
    input  wire [5:0] p_body1_x, p_body1_y,
    input  wire [5:0] p_body2_x, p_body2_y,
    input  wire [5:0] p_body3_x, p_body3_y,
    input  wire [5:0] p_body4_x, p_body4_y,
    input  wire [5:0] p_body5_x, p_body5_y,
    input  wire [5:0] p_body6_x, p_body6_y,
    input  wire [3:0] p_length,

    // Food
    input  wire [5:0] food_x,
    input  wire [5:0] food_y,

    // Output: chosen absolute direction
    output wire [1:0] rival_turn_req
);

    // Obstacle positions (duplicated from game core -- static constants)
    localparam [5:0] OBS0_X = 6'd20, OBS0_Y = 6'd8;
    localparam [5:0] OBS1_X = 6'd20, OBS1_Y = 6'd9;
    localparam [5:0] OBS2_X = 6'd20, OBS2_Y = 6'd10;
    localparam [5:0] OBS3_X = 6'd21, OBS3_Y = 6'd10;
    localparam [5:0] OBS4_X = 6'd22, OBS4_Y = 6'd10;

    // Three candidate directions
    wire [1:0] dir_fwd   = r_direction;
    wire [1:0] dir_left  = r_direction - 2'd1;
    wire [1:0] dir_right = r_direction + 2'd1;

    // Compute candidate positions
    function [11:0] next_pos;  // {x[5:0], y[5:0]}
        input [1:0] dir;
        input [5:0] hx, hy;
        reg [5:0] nx, ny;
        begin
            nx = hx;
            ny = hy;
            case (dir)
                2'b00: ny = hy - 6'd1;  // up
                2'b01: nx = hx + 6'd1;  // right
                2'b10: ny = hy + 6'd1;  // down
                2'b11: nx = hx - 6'd1;  // left
            endcase
            next_pos = {nx, ny};
        end
    endfunction

    wire [11:0] pos_fwd   = next_pos(dir_fwd,   r_head_x, r_head_y);
    wire [11:0] pos_left  = next_pos(dir_left,  r_head_x, r_head_y);
    wire [11:0] pos_right = next_pos(dir_right, r_head_x, r_head_y);

    wire [5:0] fx = pos_fwd[11:6],   fy = pos_fwd[5:0];
    wire [5:0] lx = pos_left[11:6],  ly = pos_left[5:0];
    wire [5:0] rx = pos_right[11:6], ry = pos_right[5:0];

    // --- Safety checks ---

    // Wall check (unsigned: underflow wraps to >MAX)
    function is_wall;
        input [5:0] tx, ty;
        is_wall = (tx > ARENA_X_MAX) || (ty > ARENA_Y_MAX);
    endfunction

    // Obstacle check
    function is_obstacle;
        input [5:0] tx, ty;
        is_obstacle = (tx == OBS0_X && ty == OBS0_Y) ||
                      (tx == OBS1_X && ty == OBS1_Y) ||
                      (tx == OBS2_X && ty == OBS2_Y) ||
                      (tx == OBS3_X && ty == OBS3_Y) ||
                      (tx == OBS4_X && ty == OBS4_Y);
    endfunction

    // Rival self-body check
    function is_own_body;
        input [5:0] tx, ty;
        is_own_body =
            (tx == r_body0_x && ty == r_body0_y) ||
            (r_length > 4'd2 && tx == r_body1_x && ty == r_body1_y) ||
            (r_length > 4'd3 && tx == r_body2_x && ty == r_body2_y) ||
            (r_length > 4'd4 && tx == r_body3_x && ty == r_body3_y) ||
            (r_length > 4'd5 && tx == r_body4_x && ty == r_body4_y) ||
            (r_length > 4'd6 && tx == r_body5_x && ty == r_body5_y) ||
            (r_length > 4'd7 && tx == r_body6_x && ty == r_body6_y);
    endfunction

    // Player body check (head + visible body)
    function is_player;
        input [5:0] tx, ty;
        is_player =
            (tx == p_head_x  && ty == p_head_y) ||
            (tx == p_body0_x && ty == p_body0_y) ||
            (p_length > 4'd2 && tx == p_body1_x && ty == p_body1_y) ||
            (p_length > 4'd3 && tx == p_body2_x && ty == p_body2_y) ||
            (p_length > 4'd4 && tx == p_body3_x && ty == p_body3_y) ||
            (p_length > 4'd5 && tx == p_body4_x && ty == p_body4_y) ||
            (p_length > 4'd6 && tx == p_body5_x && ty == p_body5_y) ||
            (p_length > 4'd7 && tx == p_body6_x && ty == p_body6_y);
    endfunction

    function is_unsafe;
        input [5:0] tx, ty;
        is_unsafe = is_wall(tx, ty) || is_obstacle(tx, ty) ||
                    is_own_body(tx, ty) || is_player(tx, ty);
    endfunction

    wire fwd_safe   = !is_unsafe(fx, fy);
    wire left_safe  = !is_unsafe(lx, ly);
    wire right_safe = !is_unsafe(rx, ry);

    // --- Manhattan distance to food ---
    function [6:0] manhattan;
        input [5:0] ax, ay, bx, by;
        reg [5:0] dx, dy;
        begin
            dx = (ax >= bx) ? (ax - bx) : (bx - ax);
            dy = (ay >= by) ? (ay - by) : (by - ay);
            manhattan = {1'b0, dx} + {1'b0, dy};
        end
    endfunction

    wire [6:0] dist_fwd   = manhattan(fx, fy, food_x, food_y);
    wire [6:0] dist_left  = manhattan(lx, ly, food_x, food_y);
    wire [6:0] dist_right = manhattan(rx, ry, food_x, food_y);

    // --- Selection logic ---
    // Among safe candidates, pick smallest distance. Tie-break: fwd > left > right.
    reg [1:0] chosen_dir;

    always @(*) begin
        chosen_dir = dir_fwd;  // default: forward (even if unsafe)

        if (fwd_safe && left_safe && right_safe) begin
            // All safe: pick best distance with tie-break
            if (dist_fwd <= dist_left && dist_fwd <= dist_right)
                chosen_dir = dir_fwd;
            else if (dist_left <= dist_right)
                chosen_dir = dir_left;
            else
                chosen_dir = dir_right;
        end else if (fwd_safe && left_safe) begin
            chosen_dir = (dist_fwd <= dist_left) ? dir_fwd : dir_left;
        end else if (fwd_safe && right_safe) begin
            chosen_dir = (dist_fwd <= dist_right) ? dir_fwd : dir_right;
        end else if (left_safe && right_safe) begin
            chosen_dir = (dist_left <= dist_right) ? dir_left : dir_right;
        end else if (fwd_safe) begin
            chosen_dir = dir_fwd;
        end else if (left_safe) begin
            chosen_dir = dir_left;
        end else if (right_safe) begin
            chosen_dir = dir_right;
        end else begin
            chosen_dir = dir_fwd;  // no safe option: forward and die
        end
    end

    assign rival_turn_req = chosen_dir;

endmodule
