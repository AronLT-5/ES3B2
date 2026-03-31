`timescale 1ns / 1ps

module tb_clk_divider;

    reg clk_in;
    reg reset_n;
    wire clk_out;

    clk_divider dut (
        .clk_in  (clk_in),
        .reset_n (reset_n),
        .clk_out (clk_out)
    );

    initial begin
        clk_in = 1'b0;
        reset_n = 1'b0;

        #20;
        reset_n = 1'b1;

        #200;
        $finish;
    end

    always #5 clk_in = ~clk_in;

endmodule