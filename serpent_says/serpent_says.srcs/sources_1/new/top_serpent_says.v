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

assign VGA_HS = 1'b1;
assign VGA_VS = 1'b1;
assign VGA_R  = 4'b0000;
assign VGA_G  = 4'b0000;
assign VGA_B  = 4'b0000;

endmodule