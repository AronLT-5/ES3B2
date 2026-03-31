`timescale 1ns / 1ps

module tb_top_serpent_says;

    reg CLK100MHZ;
    reg CPU_RESETN;
    reg BTNL;
    reg BTNR;

    wire VGA_HS;
    wire VGA_VS;
    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;

    top_serpent_says #(
        .GAME_TICK_COUNT_MAX(100)  // 100 clk_25mhz cycles = 4 us per tick
    ) dut (
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .BTNL(BTNL),
        .BTNR(BTNR),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B)
    );

    initial begin
        CLK100MHZ  = 1'b0;
        CPU_RESETN = 1'b0;
        BTNL       = 1'b0;
        BTNR       = 1'b0;

        // Reset
        #100;
        CPU_RESETN = 1'b1;

        // Wait ~3 game ticks (snake moves right: head 5->6->7->8)
        #12000;

        // Pulse BTNR: turn right (right -> down)
        BTNR = 1'b1;
        #200;
        BTNR = 1'b0;

        // Wait ~3 game ticks (snake moves down)
        #12000;

        // Pulse BTNL: turn left (down -> right)
        BTNL = 1'b1;
        #200;
        BTNL = 1'b0;

        // Wait ~3 game ticks (snake moves right again)
        #12000;

        $finish;
    end

    always #5 CLK100MHZ = ~CLK100MHZ;

endmodule
