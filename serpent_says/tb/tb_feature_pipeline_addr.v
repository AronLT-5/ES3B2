`timescale 1ns / 1ps

// Minimal self-checking testbench for the fb_addr_d delay register
// in feature_pipeline.v. Proves:
//   1. After reset, fb_addr_d == 0
//   2. After reset release, fb_addr_d follows fb_addr by one clock
//   3. The windowing address path does not go X/unknown

module tb_feature_pipeline_addr;

    reg        clk, rst_n;
    reg signed [15:0] fb_data;
    reg        fb_ready;

    wire [7:0]  fb_addr;
    wire        fb_consumed;
    wire signed [15:0] ctx_mel_in;
    wire [3:0]  ctx_mel_idx;
    wire        ctx_mel_we;
    wire        ctx_frame_done;
    wire        busy;

    feature_pipeline dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .fb_addr       (fb_addr),
        .fb_data       (fb_data),
        .fb_ready      (fb_ready),
        .fb_consumed   (fb_consumed),
        .ctx_mel_in    (ctx_mel_in),
        .ctx_mel_idx   (ctx_mel_idx),
        .ctx_mel_we    (ctx_mel_we),
        .ctx_frame_done(ctx_frame_done),
        .busy          (busy)
    );

    always #20 clk = ~clk;  // 25 MHz

    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input [31:0] actual;
        input [31:0] expected;
        input [159:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL %0s: got %0d expected %0d", label, actual, expected);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task check_not_x;
        input [7:0] val;
        input [159:0] label;
        begin
            if (^val === 1'bx) begin
                $display("FAIL %0s: value is X/unknown", label);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== tb_feature_pipeline_addr ===");
        clk = 0; rst_n = 0;
        fb_data = 16'sd1000;
        fb_ready = 0;

        // Hold reset for several cycles
        #200;

        // T1: fb_addr_d == 0 during reset
        check(dut.fb_addr_d, 8'd0, "T1:reset_fb_addr_d");
        check(dut.fb_addr, 8'd0, "T1:reset_fb_addr");

        // Release reset
        rst_n = 1;
        @(posedge clk); @(posedge clk);

        // T2: fb_addr_d still 0 after reset release (no frame started)
        check(dut.fb_addr_d, 8'd0, "T2:post_reset_fb_addr_d");
        check_not_x(dut.fb_addr_d, "T2:not_x_fb_addr_d");

        // T3: Start a frame — fb_addr should begin incrementing, fb_addr_d follows one cycle behind
        fb_ready = 1;
        @(posedge clk);
        fb_ready = 0;

        // Wait a few cycles for P_WINDOW to start driving fb_addr
        @(posedge clk); // FSM transitions to P_WINDOW, fb_addr set to 0
        @(posedge clk); // fb_addr = 0 (win_idx=0), fb_addr_d should be prev fb_addr
        @(posedge clk); // fb_addr = 1 (win_idx=1), fb_addr_d = 0

        // At this point fb_addr should be advancing and fb_addr_d should trail by 1 cycle
        check_not_x(dut.fb_addr_d, "T3a:not_x_fb_addr_d");
        check_not_x(dut.fb_addr, "T3b:not_x_fb_addr");

        // Let the windowing run a few more cycles and verify the delay relationship
        @(posedge clk);
        begin : check_delay
            reg [7:0] prev_addr;
            prev_addr = dut.fb_addr;
            @(posedge clk);
            check(dut.fb_addr_d, prev_addr, "T4:delay_one_cycle");
        end

        // T5: Verify windowed_sample path is not X
        @(posedge clk);
        if (^dut.windowed_sample === 1'bx) begin
            $display("FAIL T5:windowed_sample is X");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T5:windowed_sample_not_x");
            pass_count = pass_count + 1;
        end

        // Summary
        $display("\n===========================");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
