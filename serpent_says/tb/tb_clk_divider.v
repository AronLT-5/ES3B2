`timescale 1ns / 1ps

module tb_clk_divider;

    reg CLK100MHZ;
    reg reset_n;

    wire clk_25mhz;
    wire clk_out;
    wire [1:0] div_cnt;

    assign clk_out = clk_25mhz;
    assign div_cnt = dut.div_cnt;

    clk_divider dut (
        .clk_in  (CLK100MHZ),
        .reset_n (reset_n),
        .clk_out (clk_25mhz)
    );

    always #5 CLK100MHZ = ~CLK100MHZ;

    integer pass_count;
    integer fail_count;

    task check;
        input condition;
        input [159:0] label;
        begin
            if (!condition) begin
                $display("FAIL %0s at %0t: div_cnt=%b clk_25mhz=%0b reset_n=%0b",
                    label, $time, div_cnt, clk_25mhz, reset_n);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s at %0t: div_cnt=%b clk_25mhz=%0b reset_n=%0b",
                    label, $time, div_cnt, clk_25mhz, reset_n);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
`ifdef DUMP_VCD
        $dumpfile("tb_clk_divider.vcd");
        $dumpvars(0, tb_clk_divider);
`endif
    end

    initial begin
        $display("=== W2 tb_clk_divider ===");
        CLK100MHZ = 1'b0;
        reset_n = 1'b0;
        pass_count = 0;
        fail_count = 0;

        repeat (4) @(posedge CLK100MHZ);
        #1;
        check(div_cnt == 2'b00 && clk_25mhz == 1'b0, "reset_clears_divider");

        reset_n = 1'b1;
        @(posedge CLK100MHZ); #1; check(div_cnt == 2'b01 && clk_25mhz == 1'b0, "count_1");
        @(posedge CLK100MHZ); #1; check(div_cnt == 2'b10 && clk_25mhz == 1'b1, "count_2_output_high");
        @(posedge CLK100MHZ); #1; check(div_cnt == 2'b11 && clk_25mhz == 1'b1, "count_3_output_high");
        @(posedge CLK100MHZ); #1; check(div_cnt == 2'b00 && clk_25mhz == 1'b0, "count_wrap_output_low");

        repeat (12) @(posedge CLK100MHZ);

        reset_n = 1'b0;
        @(posedge CLK100MHZ); #1;
        check(div_cnt == 2'b00 && clk_25mhz == 1'b0, "reset_returns_known_state");

        $display("W2 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("W2 ALL TESTS PASSED");
            $finish;
        end else begin
            $display("W2 SOME TESTS FAILED");
            $fatal;
        end
    end

endmodule
