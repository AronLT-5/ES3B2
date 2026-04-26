`timescale 1ns / 1ps

module tb_feature_pipeline_addr;

    reg clk, reset_n;
    reg fb_ready;
    reg signed [15:0] fb_data;

    wire [7:0]  fb_addr;
    wire        fb_consumed;
    wire signed [15:0] ctx_mel_in;
    wire [3:0]  ctx_mel_idx;
    wire        ctx_mel_we;
    wire        ctx_frame_done;
    wire        busy;

    reg signed [15:0] frame_mem [0:255];
    reg signed [15:0] hann_mem [0:255];

    wire       frame_ready = fb_ready;
    wire [7:0] fb_addr_d = dut.fb_addr_d;
    wire       sample_valid = dut.fft_din_we;
    wire       fft_load_valid = dut.fft_din_we;
    wire signed [15:0] hann_coeff = hann_mem[fb_addr_d];
    wire signed [15:0] windowed_sample = dut.windowed_sample;
    wire       fft_start = dut.fft_start;
    wire       fft_done = dut.fft_done;
    wire       mel_start = dut.mel_start;
    wire       mel_valid = ctx_mel_we;
    wire [3:0] mel_bin = ctx_mel_idx;

    feature_pipeline dut (
        .clk(clk),
        .rst_n(reset_n),
        .fb_addr(fb_addr),
        .fb_data(fb_data),
        .fb_ready(fb_ready),
        .fb_consumed(fb_consumed),
        .ctx_mel_in(ctx_mel_in),
        .ctx_mel_idx(ctx_mel_idx),
        .ctx_mel_we(ctx_mel_we),
        .ctx_frame_done(ctx_frame_done),
        .busy(busy)
    );

    always #20 clk = ~clk;

    integer pass_count, fail_count;
    integer i;
    integer timeout_count;
    integer ctx_write_count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            fb_data <= 16'sd0;
        else
            fb_data <= frame_mem[fb_addr];
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            ctx_write_count <= 0;
        else if (ctx_mel_we)
            ctx_write_count <= ctx_write_count + 1;
    end

    task check;
        input condition;
        input [159:0] label;
        begin
            if (!condition) begin
                $display("FAIL W9 %0s at %0t", label, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W9 %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== W9 tb_feature_pipeline_addr ===");
        clk = 0;
        reset_n = 0;
        fb_ready = 0;
        fb_data = 0;
        pass_count = 0;
        fail_count = 0;
        timeout_count = 0;
        ctx_write_count = 0;

        for (i = 0; i < 256; i = i + 1)
            frame_mem[i] = $signed(i * 16 - 2048);
        $readmemh("hann_window.mem", hann_mem);

        repeat (5) @(posedge clk);
        check(fb_addr == 8'd0 && fb_addr_d == 8'd0 && busy == 1'b0, "reset_known_state");

        reset_n = 1'b1;
        repeat (2) @(posedge clk);

        @(negedge clk);
        fb_ready = 1'b1;

        wait (sample_valid == 1'b1);
        #1;
        check(fb_addr_d !== fb_addr, "delayed_address_differs_from_new_request");
        check(fb_data === frame_mem[fb_addr_d], "fb_data_matches_delayed_address");
        check(^windowed_sample !== 1'bx && ^hann_coeff !== 1'bx, "window_path_has_no_unknowns");

        wait (fb_consumed == 1'b1);
        @(negedge clk);
        fb_ready = 1'b0;

        wait (fft_start == 1'b1);
        wait (fft_done == 1'b1);
        check(fft_done == 1'b1, "fft_completes");

        wait (mel_start == 1'b1);

        while (ctx_frame_done != 1'b1 && timeout_count < 20000) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end
        #1;
        check(ctx_frame_done == 1'b1, "context_frame_done_pulses");
        check(ctx_write_count >= 15, "context_values_written");
        check(^ctx_mel_in !== 1'bx && ^mel_bin !== 1'bx, "context_output_has_no_unknowns");

        $display("W9 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("W9 ALL TESTS PASSED");
        else                 $display("W9 SOME TESTS FAILED");
        $finish;
    end

endmodule
