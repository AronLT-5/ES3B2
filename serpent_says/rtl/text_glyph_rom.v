`timescale 1ns / 1ps

// Tiny 5x7 bitmap font ROM for info-bar text rendering.
// Covers A-Z, 0-9, space, colon, equals, slash, pipe, dash, period.
// Character cell is 6 wide x 8 tall (col 5 always 0 for spacing, row 7 always 0).
// pixel_on = 1 means foreground.

module text_glyph_rom (
    input  wire [6:0] char_code,  // ASCII code
    input  wire [2:0] row,        // 0..7 within glyph
    input  wire [2:0] col,        // 0..5 within cell (col 5 = spacing = 0)
    output wire       pixel_on
);

    reg [4:0] glyph_row;  // 5 bits per row, MSB = leftmost pixel

    always @(*) begin
        glyph_row = 5'b00000;
        if (row < 3'd7 && col < 3'd5) begin
            case (char_code)
                // A
                7'h41: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11111;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // B
                7'h42: case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b11110;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b11110;
                    default: glyph_row = 5'b00000;
                endcase
                // C
                7'h43: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b10000;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // D
                7'h44: case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b11110;
                    default: glyph_row = 5'b00000;
                endcase
                // E
                7'h45: case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                // F
                7'h46: case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b10000;
                    default: glyph_row = 5'b00000;
                endcase
                // G
                7'h47: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b10111;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // H
                7'h48: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11111;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // I
                7'h49: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // J
                7'h4A: case (row)
                    3'd0: glyph_row = 5'b00111;
                    3'd1: glyph_row = 5'b00010;
                    3'd2: glyph_row = 5'b00010;
                    3'd3: glyph_row = 5'b00010;
                    3'd4: glyph_row = 5'b00010;
                    3'd5: glyph_row = 5'b10010;
                    3'd6: glyph_row = 5'b01100;
                    default: glyph_row = 5'b00000;
                endcase
                // K
                7'h4B: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10010;
                    3'd2: glyph_row = 5'b10100;
                    3'd3: glyph_row = 5'b11000;
                    3'd4: glyph_row = 5'b10100;
                    3'd5: glyph_row = 5'b10010;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // L
                7'h4C: case (row)
                    3'd0: glyph_row = 5'b10000;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b10000;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                // M
                7'h4D: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b11011;
                    3'd2: glyph_row = 5'b10101;
                    3'd3: glyph_row = 5'b10101;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // N
                7'h4E: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b11001;
                    3'd2: glyph_row = 5'b10101;
                    3'd3: glyph_row = 5'b10011;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // O
                7'h4F: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // P
                7'h50: case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10000;
                    3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b10000;
                    default: glyph_row = 5'b00000;
                endcase
                // Q
                7'h51: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10101;
                    3'd5: glyph_row = 5'b10010;
                    3'd6: glyph_row = 5'b01101;
                    default: glyph_row = 5'b00000;
                endcase
                // R
                7'h52: case (row)
                    3'd0: glyph_row = 5'b11110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10100;
                    3'd5: glyph_row = 5'b10010;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // S
                7'h53: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b01110;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // T
                7'h54: case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00000;
                endcase
                // U
                7'h55: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // V
                7'h56: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10001;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b01010;
                    3'd6: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00000;
                endcase
                // W
                7'h57: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b10101;
                    3'd4: glyph_row = 5'b10101;
                    3'd5: glyph_row = 5'b11011;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // X
                7'h58: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b01010;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b01010;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b10001;
                    default: glyph_row = 5'b00000;
                endcase
                // Y
                7'h59: case (row)
                    3'd0: glyph_row = 5'b10001;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b01010;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00000;
                endcase
                // Z
                7'h5A: case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b00001;
                    3'd2: glyph_row = 5'b00010;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b01000;
                    3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                // 0
                7'h30: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10011;
                    3'd3: glyph_row = 5'b10101;
                    3'd4: glyph_row = 5'b11001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // 1
                7'h31: case (row)
                    3'd0: glyph_row = 5'b00100;
                    3'd1: glyph_row = 5'b01100;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // 2
                7'h32: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b00001;
                    3'd3: glyph_row = 5'b00110;
                    3'd4: glyph_row = 5'b01000;
                    3'd5: glyph_row = 5'b10000;
                    3'd6: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                // 3
                7'h33: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b00001;
                    3'd3: glyph_row = 5'b00110;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // 4
                7'h34: case (row)
                    3'd0: glyph_row = 5'b00010;
                    3'd1: glyph_row = 5'b00110;
                    3'd2: glyph_row = 5'b01010;
                    3'd3: glyph_row = 5'b10010;
                    3'd4: glyph_row = 5'b11111;
                    3'd5: glyph_row = 5'b00010;
                    3'd6: glyph_row = 5'b00010;
                    default: glyph_row = 5'b00000;
                endcase
                // 5
                7'h35: case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b11110;
                    3'd3: glyph_row = 5'b00001;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // 6
                7'h36: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10000;
                    3'd2: glyph_row = 5'b10000;
                    3'd3: glyph_row = 5'b11110;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // 7
                7'h37: case (row)
                    3'd0: glyph_row = 5'b11111;
                    3'd1: glyph_row = 5'b00001;
                    3'd2: glyph_row = 5'b00010;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b01000;
                    3'd5: glyph_row = 5'b01000;
                    3'd6: glyph_row = 5'b01000;
                    default: glyph_row = 5'b00000;
                endcase
                // 8
                7'h38: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b01110;
                    3'd4: glyph_row = 5'b10001;
                    3'd5: glyph_row = 5'b10001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // 9
                7'h39: case (row)
                    3'd0: glyph_row = 5'b01110;
                    3'd1: glyph_row = 5'b10001;
                    3'd2: glyph_row = 5'b10001;
                    3'd3: glyph_row = 5'b01111;
                    3'd4: glyph_row = 5'b00001;
                    3'd5: glyph_row = 5'b00001;
                    3'd6: glyph_row = 5'b01110;
                    default: glyph_row = 5'b00000;
                endcase
                // Space
                7'h20: glyph_row = 5'b00000;
                // : (colon)
                7'h3A: case (row)
                    3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00000;
                endcase
                // = (equals)
                7'h3D: case (row)
                    3'd2: glyph_row = 5'b11111;
                    3'd4: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                // / (slash)
                7'h2F: case (row)
                    3'd0: glyph_row = 5'b00001;
                    3'd1: glyph_row = 5'b00010;
                    3'd2: glyph_row = 5'b00010;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b01000;
                    3'd5: glyph_row = 5'b01000;
                    3'd6: glyph_row = 5'b10000;
                    default: glyph_row = 5'b00000;
                endcase
                // | (pipe)
                7'h7C: case (row)
                    3'd0: glyph_row = 5'b00100;
                    3'd1: glyph_row = 5'b00100;
                    3'd2: glyph_row = 5'b00100;
                    3'd3: glyph_row = 5'b00100;
                    3'd4: glyph_row = 5'b00100;
                    3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00000;
                endcase
                // - (dash)
                7'h2D: case (row)
                    3'd3: glyph_row = 5'b11111;
                    default: glyph_row = 5'b00000;
                endcase
                // . (period)
                7'h2E: case (row)
                    3'd5: glyph_row = 5'b00100;
                    3'd6: glyph_row = 5'b00100;
                    default: glyph_row = 5'b00000;
                endcase
                default: glyph_row = 5'b00000;
            endcase
        end
    end

    // MSB of glyph_row is the leftmost pixel (col=0).
    // Guard col < 5 to prevent out-of-range bit select on the 5-bit glyph_row.
    assign pixel_on = (col < 3'd5) ? glyph_row[3'd4 - col] : 1'b0;

endmodule
