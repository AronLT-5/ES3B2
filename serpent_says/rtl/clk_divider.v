`timescale 1ns / 1ps

module clk_divider (
    input  wire clk_in,
    input  wire reset_n,
    output wire clk_out
);

    reg [1:0] div_cnt;

    always @(posedge clk_in or negedge reset_n) begin
        if (!reset_n)
            div_cnt <= 2'b00;
        else
            div_cnt <= div_cnt + 2'b01;
    end

    assign clk_out = div_cnt[1];

endmodule