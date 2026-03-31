`timescale 1ns / 1ps

module tb_top_serpent_says;

    reg CLK100MHZ;
    reg CPU_RESETN;

    wire VGA_HS;
    wire VGA_VS;
    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;

    top_serpent_says dut (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B)
    );

    initial begin
        CLK100MHZ = 1'b0;
        CPU_RESETN = 1'b0;

        #100;
        CPU_RESETN = 1'b1;

        #10000000;
        $finish;
    end

    always #5 CLK100MHZ = ~CLK100MHZ;

endmodule