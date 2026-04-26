`timescale 1ns / 1ps

module tb_command_filter;

    reg clk, reset_n;
    reg voice_mode_en;
    reg [1:0] kws_class;
    reg signed [7:0] kws_conf;
    reg signed [7:0] kws_second;
    reg kws_valid;

    wire [1:0] voice_kws_class;
    wire [7:0] voice_kws_conf;
    wire       voice_kws_valid;
    wire [1:0] voice_turn_req;
    wire       voice_turn_valid;
    wire [1:0] last_cmd;
    wire [7:0] last_cmd_conf;
    wire       ml_alive;

    wire signed [7:0] conf_margin = kws_conf - kws_second;
    wire cooldown_active = dut.cooldown_active;
    wire [25:0] cooldown_cnt = dut.cooldown_cnt;

    command_filter #(
        .CONF_THRESH(8'sd5),
        .MARGIN_THRESH(8'sd3),
        .COOLDOWN_TICKS(6)
    ) dut (
        .clk(clk),
        .rst_n(reset_n),
        .voice_mode_en(voice_mode_en),
        .kws_class_i(kws_class),
        .kws_conf_i(kws_conf),
        .kws_second_i(kws_second),
        .kws_valid_i(kws_valid),
        .voice_kws_class(voice_kws_class),
        .voice_kws_conf(voice_kws_conf),
        .voice_kws_valid(voice_kws_valid),
        .voice_turn_req(voice_turn_req),
        .voice_turn_valid(voice_turn_valid),
        .last_cmd(last_cmd),
        .last_cmd_conf(last_cmd_conf),
        .ml_alive(ml_alive)
    );

    always #20 clk = ~clk;

    integer pass_count, fail_count;

    task check;
        input condition;
        input [159:0] label;
        begin
            if (!condition) begin
                $display("FAIL W10 %0s at %0t", label, $time);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS W10 %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task infer_once;
        input [127:0] name;
        input [1:0] cls;
        input signed [7:0] conf;
        input signed [7:0] second;
        begin
            @(negedge clk);
            kws_class = cls;
            kws_conf = conf;
            kws_second = second;
            kws_valid = 1'b1;
            @(posedge clk); #1;
            @(negedge clk);
            kws_valid = 1'b0;
        end
    endtask

    task wait_cooldown_clear;
        begin
            while (cooldown_active) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $display("=== W10 tb_command_filter ===");
        clk = 0;
        reset_n = 0;
        voice_mode_en = 0;
        kws_class = 2'd0;
        kws_conf = 8'sd0;
        kws_second = 8'sd0;
        kws_valid = 0;
        pass_count = 0;
        fail_count = 0;

        repeat (4) @(posedge clk);
        check(voice_turn_valid == 1'b0 && last_cmd == 2'b00 && ml_alive == 1'b0, "reset_known_state");

        reset_n = 1'b1;
        repeat (2) @(posedge clk);

        infer_once("voice_disabled_left", 2'd0, 8'sd9, 8'sd1);
        check(voice_kws_valid == 1'b1 && voice_turn_valid == 1'b0 && voice_kws_class == 2'b01, "disabled_raw_updates_no_turn");

        voice_mode_en = 1'b1;

        infer_once("left_high_conf", 2'd0, 8'sd9, 8'sd1);
        check(voice_turn_valid == 1'b1 && voice_turn_req == 2'b01 && last_cmd == 2'b01, "left_command_accepted");
        check(cooldown_active == 1'b1, "cooldown_started");

        infer_once("repeat_during_cooldown", 2'd1, 8'sd9, 8'sd1);
        check(voice_turn_valid == 1'b0 && voice_kws_valid == 1'b1, "cooldown_suppresses_repeat");

        wait_cooldown_clear;

        infer_once("right_high_conf", 2'd1, 8'sd8, 8'sd1);
        check(voice_turn_valid == 1'b1 && voice_turn_req == 2'b10 && last_cmd == 2'b10, "right_command_accepted");

        wait_cooldown_clear;

        infer_once("other_class", 2'd2, 8'sd9, 8'sd0);
        check(voice_turn_valid == 1'b0 && voice_kws_class == 2'b00, "other_class_rejected");

        infer_once("low_confidence", 2'd0, 8'sd4, 8'sd0);
        check(voice_turn_valid == 1'b0, "low_confidence_rejected");

        infer_once("low_margin", 2'd1, 8'sd7, 8'sd6);
        check(conf_margin == 8'sd1 && voice_turn_valid == 1'b0, "low_margin_rejected");

        check(ml_alive === 1'b0 || ml_alive === 1'b1, "ml_alive_known_after_raw_outputs");

        $display("W10 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("W10 ALL TESTS PASSED");
        else                 $display("W10 SOME TESTS FAILED");
        $finish;
    end

endmodule
