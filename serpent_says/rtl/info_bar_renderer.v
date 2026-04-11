`timescale 1ns / 1ps

// Info bar renderer: top 100 px of the display.
// Renders text rows using text_glyph_rom and life icon sprites.
// All colour theme values are localparams for easy customization.

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

    // Life icon sprite ROM interface
    output wire [7:0]  life_sprite_addr,
    input  wire [11:0] life_sprite_data,

    // Output
    output wire        info_active,
    output wire [11:0] info_rgb
);

    // --- Colour theme (editable localparams) ---
    localparam [11:0] BG_COLOR         = 12'h112;  // dark navy
    localparam [11:0] TITLE_COLOR      = 12'hFD0;  // gold
    localparam [11:0] TEXT_COLOR       = 12'hFFF;  // white
    localparam [11:0] LABEL_COLOR      = 12'hABB;  // light grey
    localparam [11:0] VALUE_COLOR      = 12'h0F0;  // green
    localparam [11:0] RIVAL_VAL_COLOR  = 12'h4AF;  // blue
    localparam [11:0] WARN_COLOR       = 12'hF22;  // red
    localparam [11:0] PAUSE_COLOR      = 12'hFF0;  // yellow

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

    // Row Y positions (top of each text row)
    localparam ROW0_Y = 4;    // "SERPENT SAYS"
    localparam ROW1_Y = 16;   // Student IDs
    localparam ROW2_Y = 30;   // P:LEN=X LIV=X | R:LEN=X LIV=X
    localparam ROW3_Y = 44;   // MODE:BUTTON CMD:...  SRC:BTN
    localparam ROW4_Y = 58;   // State text

    // Life icon row
    localparam LIFE_ICON_Y = 74;  // y=74..89 (16px tall)
    localparam LIFE_ICON_X = 240; // starting x for life icons

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

    // --- String definitions ---
    // Row 0: "SERPENT SAYS" (12 chars)
    localparam ROW0_LEN = 12;
    localparam ROW0_X   = (640 - ROW0_LEN * CW) / 2;  // centered

    // Determine which row and character position
    reg        in_text;
    reg [11:0] text_color;
    reg [6:0]  row_char;

    // Character index in current row
    wire [9:0] rel_x_r0 = pixel_x - ROW0_X;
    wire [6:0] char_idx_r0 = rel_x_r0[9:0] / CW;

    // Row 2 starts at x=100
    localparam ROW2_X = 100;
    wire [9:0] rel_x_r2 = pixel_x - ROW2_X;
    wire [6:0] char_idx_r2 = rel_x_r2[9:0] / CW;

    // Row 3 starts at x=100
    localparam ROW3_X = 100;
    wire [9:0] rel_x_r3 = pixel_x - ROW3_X;
    wire [6:0] char_idx_r3 = rel_x_r3[9:0] / CW;

    // Row 1 starts at x=160 (shorter)
    localparam ROW1_X = 160;
    wire [9:0] rel_x_r1 = pixel_x - ROW1_X;
    wire [6:0] char_idx_r1 = rel_x_r1[9:0] / CW;

    // Row 4 starts at x=200
    localparam ROW4_X = 200;
    wire [9:0] rel_x_r4 = pixel_x - ROW4_X;
    wire [6:0] char_idx_r4 = rel_x_r4[9:0] / CW;

    // Row y-offset and col-offset for glyph
    reg [2:0] g_row, g_col;
    reg [9:0] active_row_y;

    // Digit helper: convert 4-bit value to ASCII digit
    function [6:0] digit_char;
        input [3:0] val;
        digit_char = 7'h30 + {3'b000, val};
    endfunction

    // --- Row 0: "SERPENT SAYS" ---
    function [6:0] row0_char_fn;
        input [6:0] idx;
        case (idx)
            7'd0:  row0_char_fn = 7'h53;  // S
            7'd1:  row0_char_fn = 7'h45;  // E
            7'd2:  row0_char_fn = 7'h52;  // R
            7'd3:  row0_char_fn = 7'h50;  // P
            7'd4:  row0_char_fn = 7'h45;  // E
            7'd5:  row0_char_fn = 7'h4E;  // N
            7'd6:  row0_char_fn = 7'h54;  // T
            7'd7:  row0_char_fn = 7'h20;  // (space)
            7'd8:  row0_char_fn = 7'h53;  // S
            7'd9:  row0_char_fn = 7'h41;  // A
            7'd10: row0_char_fn = 7'h59;  // Y
            7'd11: row0_char_fn = 7'h53;  // S
            default: row0_char_fn = 7'h20;
        endcase
    endfunction

    // --- Row 1: "U5560656   U5552548" ---
    localparam ROW1_LEN = 19;
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
            7'd8:  row1_char_fn = 7'h20;  // space
            7'd9:  row1_char_fn = 7'h20;  // space
            7'd10: row1_char_fn = 7'h20;  // space
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

    // --- Row 2: "P:LEN=X LIV=X | R:LEN=X LIV=X" (dynamic) ---
    // 31 chars
    localparam ROW2_LEN = 31;

    function [6:0] row2_char_fn;
        input [6:0] idx;
        input [3:0] pl, rl;
        input [1:0] plv, rlv;
        case (idx)
            7'd0:  row2_char_fn = 7'h50;  // P
            7'd1:  row2_char_fn = 7'h3A;  // :
            7'd2:  row2_char_fn = 7'h4C;  // L
            7'd3:  row2_char_fn = 7'h45;  // E
            7'd4:  row2_char_fn = 7'h4E;  // N
            7'd5:  row2_char_fn = 7'h3D;  // =
            7'd6:  row2_char_fn = digit_char(pl);
            7'd7:  row2_char_fn = 7'h20;  // space
            7'd8:  row2_char_fn = 7'h4C;  // L
            7'd9:  row2_char_fn = 7'h49;  // I
            7'd10: row2_char_fn = 7'h56;  // V
            7'd11: row2_char_fn = 7'h3D;  // =
            7'd12: row2_char_fn = digit_char({2'b00, plv});
            7'd13: row2_char_fn = 7'h20;  // space
            7'd14: row2_char_fn = 7'h7C;  // |
            7'd15: row2_char_fn = 7'h20;  // space
            7'd16: row2_char_fn = 7'h52;  // R
            7'd17: row2_char_fn = 7'h3A;  // :
            7'd18: row2_char_fn = 7'h4C;  // L
            7'd19: row2_char_fn = 7'h45;  // E
            7'd20: row2_char_fn = 7'h4E;  // N
            7'd21: row2_char_fn = 7'h3D;  // =
            7'd22: row2_char_fn = digit_char(rl);
            7'd23: row2_char_fn = 7'h20;  // space
            7'd24: row2_char_fn = 7'h4C;  // L
            7'd25: row2_char_fn = 7'h49;  // I
            7'd26: row2_char_fn = 7'h56;  // V
            7'd27: row2_char_fn = 7'h3D;  // =
            7'd28: row2_char_fn = digit_char({2'b00, rlv});
            default: row2_char_fn = 7'h20;
        endcase
    endfunction

    // --- Row 3: "MODE:BUTTON SRC:BTN CMD:NONE" or similar ---
    localparam ROW3_LEN = 32;

    function [6:0] row3_char_fn;
        input [6:0] idx;
        input       vmode;
        input [1:0] src;
        input [1:0] cmd;
        case (idx)
            // "MODE:"
            7'd0:  row3_char_fn = 7'h4D;  // M
            7'd1:  row3_char_fn = 7'h4F;  // O
            7'd2:  row3_char_fn = 7'h44;  // D
            7'd3:  row3_char_fn = 7'h45;  // E
            7'd4:  row3_char_fn = 7'h3A;  // :
            // BUTTON or VOICE (6 chars)
            7'd5:  row3_char_fn = vmode ? 7'h56 : 7'h42;  // V or B
            7'd6:  row3_char_fn = vmode ? 7'h4F : 7'h55;  // O or U
            7'd7:  row3_char_fn = vmode ? 7'h49 : 7'h54;  // I or T
            7'd8:  row3_char_fn = vmode ? 7'h43 : 7'h54;  // C or T
            7'd9:  row3_char_fn = vmode ? 7'h45 : 7'h4F;  // E or O
            7'd10: row3_char_fn = vmode ? 7'h20 : 7'h4E;  //   or N
            7'd11: row3_char_fn = 7'h20;
            // "SRC:"
            7'd12: row3_char_fn = 7'h53;  // S
            7'd13: row3_char_fn = 7'h52;  // R
            7'd14: row3_char_fn = 7'h43;  // C
            7'd15: row3_char_fn = 7'h3A;  // :
            // BTN or VCE
            7'd16: row3_char_fn = (src == 2'b10) ? 7'h56 : 7'h42;  // V or B
            7'd17: row3_char_fn = (src == 2'b10) ? 7'h43 : 7'h54;  // C or T
            7'd18: row3_char_fn = (src == 2'b10) ? 7'h45 : 7'h4E;  // E or N
            7'd19: row3_char_fn = 7'h20;
            // "CMD:"
            7'd20: row3_char_fn = 7'h43;  // C
            7'd21: row3_char_fn = 7'h4D;  // M
            7'd22: row3_char_fn = 7'h44;  // D
            7'd23: row3_char_fn = 7'h3A;  // :
            // LEFT/RIGHT/NONE (5 chars max)
            7'd24: row3_char_fn = (cmd == 2'b01) ? 7'h4C : (cmd == 2'b10) ? 7'h52 : 7'h4E;  // L/R/N
            7'd25: row3_char_fn = (cmd == 2'b01) ? 7'h45 : (cmd == 2'b10) ? 7'h49 : 7'h4F;  // E/I/O
            7'd26: row3_char_fn = (cmd == 2'b01) ? 7'h46 : (cmd == 2'b10) ? 7'h47 : 7'h4E;  // F/G/N
            7'd27: row3_char_fn = (cmd == 2'b01) ? 7'h54 : (cmd == 2'b10) ? 7'h48 : 7'h45;  // T/H/E
            7'd28: row3_char_fn = (cmd == 2'b10) ? 7'h54 : 7'h20;                             // T or space
            default: row3_char_fn = 7'h20;
        endcase
    endfunction

    // --- Row 4: State text ---
    localparam ROW4_LEN = 10;

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
                // PRESS START -> need T at 10 but we said LEN=10; just use READY
                default: row4_char_fn = 7'h20;
            endcase
            PLAYING: case (idx)
                7'd0: row4_char_fn = 7'h50;  // P
                7'd1: row4_char_fn = 7'h4C;  // L
                7'd2: row4_char_fn = 7'h41;  // A
                7'd3: row4_char_fn = 7'h59;  // Y
                7'd4: row4_char_fn = 7'h49;  // I
                7'd5: row4_char_fn = 7'h4E;  // N
                7'd6: row4_char_fn = 7'h47;  // G
                default: row4_char_fn = 7'h20;
            endcase
            PAUSED: case (idx)
                7'd0: row4_char_fn = 7'h50;  // P
                7'd1: row4_char_fn = 7'h41;  // A
                7'd2: row4_char_fn = 7'h55;  // U
                7'd3: row4_char_fn = 7'h53;  // S
                7'd4: row4_char_fn = 7'h45;  // E
                7'd5: row4_char_fn = 7'h44;  // D
                default: row4_char_fn = 7'h20;
            endcase
            VICTORY: case (idx)
                7'd0: row4_char_fn = 7'h56;  // V
                7'd1: row4_char_fn = 7'h49;  // I
                7'd2: row4_char_fn = 7'h43;  // C
                7'd3: row4_char_fn = 7'h54;  // T
                7'd4: row4_char_fn = 7'h4F;  // O
                7'd5: row4_char_fn = 7'h52;  // R
                7'd6: row4_char_fn = 7'h59;  // Y
                default: row4_char_fn = 7'h20;
            endcase
            GAME_OVER: case (idx)
                7'd0: row4_char_fn = 7'h47;  // G
                7'd1: row4_char_fn = 7'h41;  // A
                7'd2: row4_char_fn = 7'h4D;  // M
                7'd3: row4_char_fn = 7'h45;  // E
                7'd4: row4_char_fn = 7'h20;  // (space)
                7'd5: row4_char_fn = 7'h4F;  // O
                7'd6: row4_char_fn = 7'h56;  // V
                7'd7: row4_char_fn = 7'h45;  // E
                7'd8: row4_char_fn = 7'h52;  // R
                default: row4_char_fn = 7'h20;
            endcase
            3'd5: case (idx)  // RESPAWNING
                7'd0: row4_char_fn = 7'h4B;  // K
                7'd1: row4_char_fn = 7'h4F;  // O
                7'd2: row4_char_fn = 7'h21;  // !
                default: row4_char_fn = 7'h20;
            endcase
            default: row4_char_fn = 7'h20;
        endcase
    endfunction

    // --- Life icon sprite addressing ---
    // Show p_lives icons starting at LIFE_ICON_X, then gap, then r_lives icons
    wire in_life_icon_y = (pixel_y >= LIFE_ICON_Y) && (pixel_y < LIFE_ICON_Y + 16);
    wire [3:0] life_py = pixel_y - LIFE_ICON_Y;

    // Player life icons: at x = LIFE_ICON_X, LIFE_ICON_X+18, LIFE_ICON_X+36
    wire [9:0] p_life_base = LIFE_ICON_X;
    wire in_p_life0 = in_life_icon_y && (pixel_x >= p_life_base) && (pixel_x < p_life_base + 16) && (p_lives >= 2'd1);
    wire in_p_life1 = in_life_icon_y && (pixel_x >= p_life_base + 18) && (pixel_x < p_life_base + 34) && (p_lives >= 2'd2);
    wire in_p_life2 = in_life_icon_y && (pixel_x >= p_life_base + 36) && (pixel_x < p_life_base + 52) && (p_lives >= 2'd3);

    // Rival life icons: at x = LIFE_ICON_X + 100
    wire [9:0] r_life_base = LIFE_ICON_X + 100;
    wire in_r_life0 = in_life_icon_y && (pixel_x >= r_life_base) && (pixel_x < r_life_base + 16) && (r_lives >= 2'd1);
    wire in_r_life1 = in_life_icon_y && (pixel_x >= r_life_base + 18) && (pixel_x < r_life_base + 34) && (r_lives >= 2'd2);
    wire in_r_life2 = in_life_icon_y && (pixel_x >= r_life_base + 36) && (pixel_x < r_life_base + 52) && (r_lives >= 2'd3);

    wire in_any_life = in_p_life0 || in_p_life1 || in_p_life2 || in_r_life0 || in_r_life1 || in_r_life2;

    // Compute life sprite pixel offset
    reg [3:0] life_px;
    always @(*) begin
        life_px = 4'd0;
        if (in_p_life0)      life_px = pixel_x - p_life_base;
        else if (in_p_life1) life_px = pixel_x - (p_life_base + 18);
        else if (in_p_life2) life_px = pixel_x - (p_life_base + 36);
        else if (in_r_life0) life_px = pixel_x - r_life_base;
        else if (in_r_life1) life_px = pixel_x - (r_life_base + 18);
        else if (in_r_life2) life_px = pixel_x - (r_life_base + 36);
    end

    assign life_sprite_addr = {life_py, life_px};

    // --- Main rendering logic ---
    reg [11:0] pixel_out;

    always @(*) begin
        pixel_out = BG_COLOR;
        in_text = 1'b0;
        glyph_char = 7'h20;
        g_row = 3'd0;
        g_col = 3'd0;

        if (info_active) begin
            // Life icons (priority over text in their region)
            if (in_any_life && life_sprite_data != 12'h000) begin
                pixel_out = life_sprite_data;
            end
            // Row 0: title
            else if (pixel_y >= ROW0_Y && pixel_y < ROW0_Y + CH &&
                     pixel_x >= ROW0_X && pixel_x < ROW0_X + ROW0_LEN * CW) begin
                g_row = pixel_y - ROW0_Y;
                g_col = (pixel_x - ROW0_X) % CW;
                glyph_char = row0_char_fn(char_idx_r0);
                in_text = 1'b1;
                text_color = TITLE_COLOR;
            end
            // Row 1: student IDs
            else if (pixel_y >= ROW1_Y && pixel_y < ROW1_Y + CH &&
                     pixel_x >= ROW1_X && pixel_x < ROW1_X + ROW1_LEN * CW) begin
                g_row = pixel_y - ROW1_Y;
                g_col = (pixel_x - ROW1_X) % CW;
                glyph_char = row1_char_fn(char_idx_r1);
                in_text = 1'b1;
                text_color = LABEL_COLOR;
            end
            // Row 2: lengths and lives
            else if (pixel_y >= ROW2_Y && pixel_y < ROW2_Y + CH &&
                     pixel_x >= ROW2_X && pixel_x < ROW2_X + ROW2_LEN * CW) begin
                g_row = pixel_y - ROW2_Y;
                g_col = (pixel_x - ROW2_X) % CW;
                glyph_char = row2_char_fn(char_idx_r2, p_length, r_length, p_lives, r_lives);
                in_text = 1'b1;
                text_color = TEXT_COLOR;
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
                // Blink pause text
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
