`timescale 1ns / 1ps

// Info bar renderer: top 100 px of the display.
// Renders text rows (Student IDs, Score, Mode/Source/Command, State) using
// text_glyph_rom and life-indicator hearts using two 13x13 sprite ROMs
// (Heart_Blue for the player on the left, Heart_Red for the rival on the right).

module info_bar_renderer (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire        video_active,

    // Game state
    input  wire [2:0]  fsm_state,
    input  wire [3:0]  p_length,
    input  wire [1:0]  p_lives,
    input  wire [3:0]  r_length,
    input  wire [1:0]  r_lives,
    input  wire [1:0]  last_player_cmd,
    input  wire [1:0]  last_turn_source,
    input  wire        voice_mode_en,

    // Heart sprite ROM interfaces (13x13 each)
    output wire [7:0]  heart_blue_addr,
    input  wire [11:0] heart_blue_data,
    output wire [7:0]  heart_red_addr,
    input  wire [11:0] heart_red_data,

    // Output
    output wire        info_active,
    output wire [11:0] info_rgb
);

    // --- Colour theme (editable localparams) ---
    localparam [11:0] BG_COLOR         = 12'h112;  // dark navy
    localparam [11:0] TEXT_COLOR       = 12'hFFF;  // white
    localparam [11:0] LABEL_COLOR      = 12'hABB;  // light grey
    localparam [11:0] PLAYER_COLOR     = 12'h4AF;  // soft blue (matches blue heart)
    localparam [11:0] RIVAL_COLOR      = 12'hF66;  // soft red (matches red heart)
    localparam [11:0] WARN_COLOR       = 12'hF22;  // red
    localparam [11:0] PAUSE_COLOR      = 12'hFF0;  // yellow
    localparam [11:0] TITLE_COLOR      = 12'hFD0;  // gold (used for VICTORY state text)

    // FSM state encoding
    localparam IDLE      = 3'd0;
    localparam PLAYING   = 3'd1;
    localparam PAUSED    = 3'd2;
    localparam VICTORY   = 3'd3;
    localparam GAME_OVER = 3'd4;

    // --- Text row geometry ---
    // Character cell: 6 wide x 8 tall
    localparam CW = 6;
    localparam CH = 8;

    // Row Y positions (top of each text row). Layout (info bar 0..99):
    //   y=4..11   ROW1: Student IDs (moved higher; old ROW0 title removed)
    //   y=16..23  ROW2: "PLAYER SCORE : N" left,  "N : SCORE RIVAL" right
    //   y=28..40  Hearts: 3 blue (left) / 3 red (right), 13 px tall
    //   y=46..53  ROW3: MODE:.. SRC:.. CMD:..  (kept)
    //   y=60..67  ROW4: state text (kept)
    localparam ROW1_Y = 4;
    localparam ROW2_Y = 16;
    localparam ROW3_Y = 46;
    localparam ROW4_Y = 60;

    // Heart geometry
    localparam HEART_Y     = 28;
    localparam HEART_W     = 13;
    localparam HEART_H     = 13;
    localparam HEART_GAP   = 3;
    localparam HEART_STRIDE = HEART_W + HEART_GAP;        // 16

    // Player hearts hug the left margin so they sit beneath "PLAYER SCORE..."
    localparam P_HEART_X0 = 20;                            // 20, 36, 52
    localparam P_HEART_X1 = P_HEART_X0 + HEART_STRIDE;
    localparam P_HEART_X2 = P_HEART_X0 + HEART_STRIDE * 2;

    // Rival hearts hug the right margin so they sit beneath "... SCORE RIVAL"
    // 3*13 + 2*3 = 45 px total. End at x=619 -> start at x=574.
    localparam R_HEART_X0 = 640 - 21 - (3*HEART_W + 2*HEART_GAP); // 574
    localparam R_HEART_X1 = R_HEART_X0 + HEART_STRIDE;
    localparam R_HEART_X2 = R_HEART_X0 + HEART_STRIDE * 2;

    // --- Blink counter for pause text ---
    reg [23:0] blink_cnt;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) blink_cnt <= 24'd0;
        else blink_cnt <= blink_cnt + 24'd1;
    end
    wire blink = blink_cnt[22]; // ~3 Hz at 25 MHz

    // --- Text glyph ROM ---
    reg  [6:0] glyph_char;
    wire [2:0] glyph_row_idx;
    wire [2:0] glyph_col_idx;
    wire       glyph_pixel;

    text_glyph_rom u_glyph_rom (
        .char_code (glyph_char),
        .row       (glyph_row_idx),
        .col       (glyph_col_idx),
        .pixel_on  (glyph_pixel)
    );

    assign info_active = video_active && (pixel_y < 10'd100);

    // --- Score derivation (length-2 with clamp, mirroring seven_seg_driver) ---
    wire [3:0] p_score = (p_length >= 4'd2) ? (p_length - 4'd2) : 4'd0;
    wire [3:0] r_score = (r_length >= 4'd2) ? (r_length - 4'd2) : 4'd0;

    // --- Row 1: Student IDs (centred-ish, moved up to y=4) ---
    localparam ROW1_LEN = 19;
    localparam ROW1_X   = (640 - ROW1_LEN * CW) / 2;        // 640-114 -> /2 = 263
    wire [9:0] rel_x_r1 = pixel_x - ROW1_X;
    wire [6:0] char_idx_r1 = rel_x_r1[9:0] / CW;

    function [6:0] row1_char_fn;
        input [6:0] idx;
        case (idx)
            // "U5560656   U5552548"
            7'd0:  row1_char_fn = 7'h55;  // U
            7'd1:  row1_char_fn = 7'h35;  // 5
            7'd2:  row1_char_fn = 7'h35;  // 5
            7'd3:  row1_char_fn = 7'h36;  // 6
            7'd4:  row1_char_fn = 7'h30;  // 0
            7'd5:  row1_char_fn = 7'h36;  // 6
            7'd6:  row1_char_fn = 7'h35;  // 5
            7'd7:  row1_char_fn = 7'h36;  // 6
            7'd8:  row1_char_fn = 7'h20;
            7'd9:  row1_char_fn = 7'h20;
            7'd10: row1_char_fn = 7'h20;
            7'd11: row1_char_fn = 7'h55;  // U
            7'd12: row1_char_fn = 7'h35;  // 5
            7'd13: row1_char_fn = 7'h35;  // 5
            7'd14: row1_char_fn = 7'h35;  // 5
            7'd15: row1_char_fn = 7'h32;  // 2
            7'd16: row1_char_fn = 7'h35;  // 5
            7'd17: row1_char_fn = 7'h34;  // 4
            7'd18: row1_char_fn = 7'h38;  // 8
            default: row1_char_fn = 7'h20;
        endcase
    endfunction

    // --- Row 2: scores ---
    // Left text "PLAYER SCORE : <D>" (16 chars) at x=20.. (ends x=20+96=116)
    // Right text "<D> : SCORE RIVAL" (17 chars) right-aligned ending x=620
    localparam ROW2_LEFT_LEN  = 16;
    localparam ROW2_LEFT_X    = 20;

    localparam ROW2_RIGHT_LEN = 17;
    localparam ROW2_RIGHT_X   = 620 - ROW2_RIGHT_LEN * CW;  // 620 - 102 = 518

    wire [9:0] rel_x_r2l = pixel_x - ROW2_LEFT_X;
    wire [6:0] char_idx_r2l = rel_x_r2l[9:0] / CW;
    wire [9:0] rel_x_r2r = pixel_x - ROW2_RIGHT_X;
    wire [6:0] char_idx_r2r = rel_x_r2r[9:0] / CW;

    // Digit helper: convert 4-bit value to ASCII digit
    function [6:0] digit_char;
        input [3:0] val;
        digit_char = 7'h30 + {3'b000, val};
    endfunction

    // "PLAYER SCORE : <D>"
    function [6:0] row2_left_char_fn;
        input [6:0] idx;
        input [3:0] sc;
        case (idx)
            7'd0:  row2_left_char_fn = 7'h50;  // P
            7'd1:  row2_left_char_fn = 7'h4C;  // L
            7'd2:  row2_left_char_fn = 7'h41;  // A
            7'd3:  row2_left_char_fn = 7'h59;  // Y
            7'd4:  row2_left_char_fn = 7'h45;  // E
            7'd5:  row2_left_char_fn = 7'h52;  // R
            7'd6:  row2_left_char_fn = 7'h20;  // (space)
            7'd7:  row2_left_char_fn = 7'h53;  // S
            7'd8:  row2_left_char_fn = 7'h43;  // C
            7'd9:  row2_left_char_fn = 7'h4F;  // O
            7'd10: row2_left_char_fn = 7'h52;  // R
            7'd11: row2_left_char_fn = 7'h45;  // E
            7'd12: row2_left_char_fn = 7'h20;
            7'd13: row2_left_char_fn = 7'h3A;  // :
            7'd14: row2_left_char_fn = 7'h20;
            7'd15: row2_left_char_fn = digit_char(sc);
            default: row2_left_char_fn = 7'h20;
        endcase
    endfunction

    // "<D> : SCORE RIVAL"
    function [6:0] row2_right_char_fn;
        input [6:0] idx;
        input [3:0] sc;
        case (idx)
            7'd0:  row2_right_char_fn = digit_char(sc);
            7'd1:  row2_right_char_fn = 7'h20;
            7'd2:  row2_right_char_fn = 7'h3A;  // :
            7'd3:  row2_right_char_fn = 7'h20;
            7'd4:  row2_right_char_fn = 7'h53;  // S
            7'd5:  row2_right_char_fn = 7'h43;  // C
            7'd6:  row2_right_char_fn = 7'h4F;  // O
            7'd7:  row2_right_char_fn = 7'h52;  // R
            7'd8:  row2_right_char_fn = 7'h45;  // E
            7'd9:  row2_right_char_fn = 7'h20;
            7'd10: row2_right_char_fn = 7'h20;
            7'd11: row2_right_char_fn = 7'h52;  // R
            7'd12: row2_right_char_fn = 7'h49;  // I
            7'd13: row2_right_char_fn = 7'h56;  // V
            7'd14: row2_right_char_fn = 7'h41;  // A
            7'd15: row2_right_char_fn = 7'h4C;  // L
            7'd16: row2_right_char_fn = 7'h20;
            default: row2_right_char_fn = 7'h20;
        endcase
    endfunction

    // --- Row 3: MODE / SRC / CMD (unchanged content; new Y) ---
    localparam ROW3_X   = 100;
    localparam ROW3_LEN = 32;
    wire [9:0] rel_x_r3 = pixel_x - ROW3_X;
    wire [6:0] char_idx_r3 = rel_x_r3[9:0] / CW;

    function [6:0] row3_char_fn;
        input [6:0] idx;
        input       vmode;
        input [1:0] src;
        input [1:0] cmd;
        case (idx)
            7'd0:  row3_char_fn = 7'h4D;  // M
            7'd1:  row3_char_fn = 7'h4F;  // O
            7'd2:  row3_char_fn = 7'h44;  // D
            7'd3:  row3_char_fn = 7'h45;  // E
            7'd4:  row3_char_fn = 7'h3A;  // :
            7'd5:  row3_char_fn = vmode ? 7'h56 : 7'h42;
            7'd6:  row3_char_fn = vmode ? 7'h4F : 7'h55;
            7'd7:  row3_char_fn = vmode ? 7'h49 : 7'h54;
            7'd8:  row3_char_fn = vmode ? 7'h43 : 7'h54;
            7'd9:  row3_char_fn = vmode ? 7'h45 : 7'h4F;
            7'd10: row3_char_fn = vmode ? 7'h20 : 7'h4E;
            7'd11: row3_char_fn = 7'h20;
            7'd12: row3_char_fn = 7'h53;  // S
            7'd13: row3_char_fn = 7'h52;  // R
            7'd14: row3_char_fn = 7'h43;  // C
            7'd15: row3_char_fn = 7'h3A;  // :
            7'd16: row3_char_fn = (src == 2'b10) ? 7'h56 : 7'h42;
            7'd17: row3_char_fn = (src == 2'b10) ? 7'h43 : 7'h54;
            7'd18: row3_char_fn = (src == 2'b10) ? 7'h45 : 7'h4E;
            7'd19: row3_char_fn = 7'h20;
            7'd20: row3_char_fn = 7'h43;  // C
            7'd21: row3_char_fn = 7'h4D;  // M
            7'd22: row3_char_fn = 7'h44;  // D
            7'd23: row3_char_fn = 7'h3A;  // :
            7'd24: row3_char_fn = (cmd == 2'b01) ? 7'h4C : (cmd == 2'b10) ? 7'h52 : 7'h4E;
            7'd25: row3_char_fn = (cmd == 2'b01) ? 7'h45 : (cmd == 2'b10) ? 7'h49 : 7'h4F;
            7'd26: row3_char_fn = (cmd == 2'b01) ? 7'h46 : (cmd == 2'b10) ? 7'h47 : 7'h4E;
            7'd27: row3_char_fn = (cmd == 2'b01) ? 7'h54 : (cmd == 2'b10) ? 7'h48 : 7'h45;
            7'd28: row3_char_fn = (cmd == 2'b10) ? 7'h54 : 7'h20;
            default: row3_char_fn = 7'h20;
        endcase
    endfunction

    // --- Row 4: state text (unchanged content; new Y) ---
    localparam ROW4_X   = 200;
    localparam ROW4_LEN = 10;
    wire [9:0] rel_x_r4 = pixel_x - ROW4_X;
    wire [6:0] char_idx_r4 = rel_x_r4[9:0] / CW;

    function [6:0] row4_char_fn;
        input [6:0] idx;
        input [2:0] state;
        case (state)
            IDLE: case (idx)
                7'd0: row4_char_fn = 7'h50;  // P
                7'd1: row4_char_fn = 7'h52;  // R
                7'd2: row4_char_fn = 7'h45;  // E
                7'd3: row4_char_fn = 7'h53;  // S
                7'd4: row4_char_fn = 7'h53;  // S
                7'd5: row4_char_fn = 7'h20;
                7'd6: row4_char_fn = 7'h53;  // S
                7'd7: row4_char_fn = 7'h54;  // T
                7'd8: row4_char_fn = 7'h41;  // A
                7'd9: row4_char_fn = 7'h52;  // R
                default: row4_char_fn = 7'h20;
            endcase
            PLAYING: case (idx)
                7'd0: row4_char_fn = 7'h50;
                7'd1: row4_char_fn = 7'h4C;
                7'd2: row4_char_fn = 7'h41;
                7'd3: row4_char_fn = 7'h59;
                7'd4: row4_char_fn = 7'h49;
                7'd5: row4_char_fn = 7'h4E;
                7'd6: row4_char_fn = 7'h47;
                default: row4_char_fn = 7'h20;
            endcase
            PAUSED: case (idx)
                7'd0: row4_char_fn = 7'h50;
                7'd1: row4_char_fn = 7'h41;
                7'd2: row4_char_fn = 7'h55;
                7'd3: row4_char_fn = 7'h53;
                7'd4: row4_char_fn = 7'h45;
                7'd5: row4_char_fn = 7'h44;
                default: row4_char_fn = 7'h20;
            endcase
            VICTORY: case (idx)
                7'd0: row4_char_fn = 7'h56;
                7'd1: row4_char_fn = 7'h49;
                7'd2: row4_char_fn = 7'h43;
                7'd3: row4_char_fn = 7'h54;
                7'd4: row4_char_fn = 7'h4F;
                7'd5: row4_char_fn = 7'h52;
                7'd6: row4_char_fn = 7'h59;
                default: row4_char_fn = 7'h20;
            endcase
            GAME_OVER: case (idx)
                7'd0: row4_char_fn = 7'h47;
                7'd1: row4_char_fn = 7'h41;
                7'd2: row4_char_fn = 7'h4D;
                7'd3: row4_char_fn = 7'h45;
                7'd4: row4_char_fn = 7'h20;
                7'd5: row4_char_fn = 7'h4F;
                7'd6: row4_char_fn = 7'h56;
                7'd7: row4_char_fn = 7'h45;
                7'd8: row4_char_fn = 7'h52;
                default: row4_char_fn = 7'h20;
            endcase
            3'd5: case (idx)  // RESPAWNING
                7'd0: row4_char_fn = 7'h4B;
                7'd1: row4_char_fn = 7'h4F;
                7'd2: row4_char_fn = 7'h21;
                default: row4_char_fn = 7'h20;
            endcase
            default: row4_char_fn = 7'h20;
        endcase
    endfunction

    // --- Heart icon hit detection ---
    wire in_heart_y = (pixel_y >= HEART_Y) && (pixel_y < HEART_Y + HEART_H);

    // Player heart slots (gated by p_lives)
    wire in_p_h0 = in_heart_y && (pixel_x >= P_HEART_X0) && (pixel_x < P_HEART_X0 + HEART_W) && (p_lives >= 2'd1);
    wire in_p_h1 = in_heart_y && (pixel_x >= P_HEART_X1) && (pixel_x < P_HEART_X1 + HEART_W) && (p_lives >= 2'd2);
    wire in_p_h2 = in_heart_y && (pixel_x >= P_HEART_X2) && (pixel_x < P_HEART_X2 + HEART_W) && (p_lives >= 2'd3);
    wire in_p_heart = in_p_h0 || in_p_h1 || in_p_h2;

    // Rival heart slots (gated by r_lives)
    wire in_r_h0 = in_heart_y && (pixel_x >= R_HEART_X0) && (pixel_x < R_HEART_X0 + HEART_W) && (r_lives >= 2'd1);
    wire in_r_h1 = in_heart_y && (pixel_x >= R_HEART_X1) && (pixel_x < R_HEART_X1 + HEART_W) && (r_lives >= 2'd2);
    wire in_r_h2 = in_heart_y && (pixel_x >= R_HEART_X2) && (pixel_x < R_HEART_X2 + HEART_W) && (r_lives >= 2'd3);
    wire in_r_heart = in_r_h0 || in_r_h1 || in_r_h2;

    // Pixel offset within whichever heart we're inside (max 12 -> 4 bits)
    wire [3:0] heart_py = pixel_y - HEART_Y;

    reg [3:0] p_heart_px;
    always @(*) begin
        p_heart_px = 4'd0;
        if      (in_p_h0) p_heart_px = pixel_x - P_HEART_X0;
        else if (in_p_h1) p_heart_px = pixel_x - P_HEART_X1;
        else if (in_p_h2) p_heart_px = pixel_x - P_HEART_X2;
    end

    reg [3:0] r_heart_px;
    always @(*) begin
        r_heart_px = 4'd0;
        if      (in_r_h0) r_heart_px = pixel_x - R_HEART_X0;
        else if (in_r_h1) r_heart_px = pixel_x - R_HEART_X1;
        else if (in_r_h2) r_heart_px = pixel_x - R_HEART_X2;
    end

    // addr = py * 13 + px ;  13 = 8 + 4 + 1
    wire [7:0] heart_py_ext  = {4'b0, heart_py};
    wire [7:0] heart_py_x13  = (heart_py_ext << 3) + (heart_py_ext << 2) + heart_py_ext;
    assign heart_blue_addr = heart_py_x13 + {4'b0, p_heart_px};
    assign heart_red_addr  = heart_py_x13 + {4'b0, r_heart_px};

    // --- Main rendering logic ---
    reg [11:0] pixel_out;
    reg        in_text;
    reg [11:0] text_color;
    reg [2:0]  g_row, g_col;

    always @(*) begin
        pixel_out = BG_COLOR;
        in_text = 1'b0;
        glyph_char = 7'h20;
        g_row = 3'd0;
        g_col = 3'd0;
        text_color = TEXT_COLOR;

        if (info_active) begin
            // Heart icons (priority over text in their region)
            if (in_p_heart && heart_blue_data != 12'h000) begin
                pixel_out = heart_blue_data;
            end
            else if (in_r_heart && heart_red_data != 12'h000) begin
                pixel_out = heart_red_data;
            end
            // Row 1: Student IDs
            else if (pixel_y >= ROW1_Y && pixel_y < ROW1_Y + CH &&
                     pixel_x >= ROW1_X && pixel_x < ROW1_X + ROW1_LEN * CW) begin
                g_row = pixel_y - ROW1_Y;
                g_col = (pixel_x - ROW1_X) % CW;
                glyph_char = row1_char_fn(char_idx_r1);
                in_text = 1'b1;
                text_color = LABEL_COLOR;
            end
            // Row 2 left: PLAYER SCORE : N
            else if (pixel_y >= ROW2_Y && pixel_y < ROW2_Y + CH &&
                     pixel_x >= ROW2_LEFT_X && pixel_x < ROW2_LEFT_X + ROW2_LEFT_LEN * CW) begin
                g_row = pixel_y - ROW2_Y;
                g_col = (pixel_x - ROW2_LEFT_X) % CW;
                glyph_char = row2_left_char_fn(char_idx_r2l, p_score);
                in_text = 1'b1;
                text_color = PLAYER_COLOR;
            end
            // Row 2 right: N : SCORE RIVAL
            else if (pixel_y >= ROW2_Y && pixel_y < ROW2_Y + CH &&
                     pixel_x >= ROW2_RIGHT_X && pixel_x < ROW2_RIGHT_X + ROW2_RIGHT_LEN * CW) begin
                g_row = pixel_y - ROW2_Y;
                g_col = (pixel_x - ROW2_RIGHT_X) % CW;
                glyph_char = row2_right_char_fn(char_idx_r2r, r_score);
                in_text = 1'b1;
                text_color = RIVAL_COLOR;
            end
            // Row 3: mode, source, command
            else if (pixel_y >= ROW3_Y && pixel_y < ROW3_Y + CH &&
                     pixel_x >= ROW3_X && pixel_x < ROW3_X + ROW3_LEN * CW) begin
                g_row = pixel_y - ROW3_Y;
                g_col = (pixel_x - ROW3_X) % CW;
                glyph_char = row3_char_fn(char_idx_r3, voice_mode_en, last_turn_source, last_player_cmd);
                in_text = 1'b1;
                text_color = LABEL_COLOR;
            end
            // Row 4: state
            else if (pixel_y >= ROW4_Y && pixel_y < ROW4_Y + CH &&
                     pixel_x >= ROW4_X && pixel_x < ROW4_X + ROW4_LEN * CW) begin
                g_row = pixel_y - ROW4_Y;
                g_col = (pixel_x - ROW4_X) % CW;
                glyph_char = row4_char_fn(char_idx_r4, fsm_state);
                in_text = 1'b1;
                if (fsm_state == PAUSED)
                    text_color = blink ? PAUSE_COLOR : BG_COLOR;
                else if (fsm_state == GAME_OVER)
                    text_color = WARN_COLOR;
                else if (fsm_state == 3'd5)  // RESPAWNING
                    text_color = blink ? WARN_COLOR : BG_COLOR;
                else if (fsm_state == VICTORY)
                    text_color = TITLE_COLOR;
                else
                    text_color = TEXT_COLOR;
            end

            // Apply glyph pixel
            if (in_text && glyph_pixel)
                pixel_out = text_color;
        end
    end

    assign glyph_row_idx = g_row;
    assign glyph_col_idx = g_col;

    assign info_rgb = pixel_out;

endmodule
