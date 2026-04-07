`timescale 1ns / 1ps

module seven_seg_driver (
    input  wire       clk,
    input  wire       reset_n,
    input  wire [3:0] p_length,
    input  wire [1:0] p_lives,
    input  wire [3:0] r_length,
    input  wire [1:0] r_lives,
    output reg  [6:0] seg,     // CA-CG, active-low
    output wire       dp,      // DP, active-low
    output reg  [7:0] an       // AN[7:0], active-low
);

    // Refresh counter: ~190 Hz per digit at 25 MHz
    // 25e6 / (8 * 2^13) ~ 381 Hz total, ~48 Hz per digit -- visible enough
    // Use bits [16:14] as digit selector for ~190 Hz per digit
    reg [16:0] refresh_cnt;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            refresh_cnt <= 17'd0;
        else
            refresh_cnt <= refresh_cnt + 17'd1;
    end

    wire [2:0] digit_sel = refresh_cnt[16:14];

    // Score = length - 2 (initial length is 2, max score 6)
    wire [3:0] p_score = (p_length >= 4'd2) ? (p_length - 4'd2) : 4'd0;
    wire [3:0] r_score = (r_length >= 4'd2) ? (r_length - 4'd2) : 4'd0;

    // 8-digit layout (AN[7]=leftmost, AN[0]=rightmost on Nexys 4 DDR):
    //   Left bank (Player):  AN[7]=score tens  AN[6]=score ones  AN[5]=blank  AN[4]=lives
    //   Right bank (Rival):  AN[3]=score tens  AN[2]=score ones  AN[1]=blank  AN[0]=lives
    reg [3:0] digit_val;
    reg       digit_blank;

    always @(*) begin
        digit_blank = 1'b0;
        digit_val   = 4'd0;
        case (digit_sel)
            3'd0: digit_val = {2'b00, r_lives};     // AN[0]: Rival lives
            3'd1: digit_blank = 1'b1;                // AN[1]: Blank separator
            3'd2: digit_val = r_score;               // AN[2]: Rival score ones
            3'd3: digit_val = 4'd0;                  // AN[3]: Rival score tens
            3'd4: digit_val = {2'b00, p_lives};      // AN[4]: Player lives
            3'd5: digit_blank = 1'b1;                // AN[5]: Blank separator
            3'd6: digit_val = p_score;               // AN[6]: Player score ones
            3'd7: digit_val = 4'd0;                  // AN[7]: Player score tens
        endcase
    end

    // Seven-segment decode (active-low: 0 = segment ON)
    //   segments: gfedcba
    reg [6:0] seg_pattern;
    always @(*) begin
        if (digit_blank)
            seg_pattern = 7'b1111111;  // all off
        else begin
            case (digit_val)
                4'h0: seg_pattern = 7'b1000000;
                4'h1: seg_pattern = 7'b1111001;
                4'h2: seg_pattern = 7'b0100100;
                4'h3: seg_pattern = 7'b0110000;
                4'h4: seg_pattern = 7'b0011001;
                4'h5: seg_pattern = 7'b0010010;
                4'h6: seg_pattern = 7'b0000010;
                4'h7: seg_pattern = 7'b1111000;
                4'h8: seg_pattern = 7'b0000000;
                4'h9: seg_pattern = 7'b0010000;
                default: seg_pattern = 7'b1111111;
            endcase
        end
    end

    // Anode selection (active-low)
    always @(*) begin
        an = 8'b11111111;
        an[digit_sel] = 1'b0;
    end

    always @(*) begin
        seg = seg_pattern;
    end

    assign dp = 1'b1;  // DP always off

endmodule
