`timescale 1ns / 1ps

module tb_turn_request_mux;

    reg  [1:0] btn_turn_req;
    reg        btn_turn_valid;
    reg  [1:0] voice_turn_req;
    reg        voice_turn_valid;
    wire [1:0] player_turn_req;
    wire       player_turn_valid;
    wire [1:0] turn_source;

    turn_request_mux dut (
        .btn_turn_req    (btn_turn_req),
        .btn_turn_valid  (btn_turn_valid),
        .voice_turn_req  (voice_turn_req),
        .voice_turn_valid(voice_turn_valid),
        .player_turn_req (player_turn_req),
        .player_turn_valid(player_turn_valid),
        .turn_source     (turn_source)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task check;
        input [1:0] exp_req;
        input       exp_valid;
        input [1:0] exp_src;
        input [79:0] label;
        begin
            #1;
            if (player_turn_req !== exp_req || player_turn_valid !== exp_valid || turn_source !== exp_src) begin
                $display("FAIL %0s: req=%b valid=%b src=%b (expected %b %b %b)",
                    label, player_turn_req, player_turn_valid, turn_source,
                    exp_req, exp_valid, exp_src);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== tb_turn_request_mux ===");

        // T1: No valid inputs -> no command
        btn_turn_req = 2'b00; btn_turn_valid = 0;
        voice_turn_req = 2'b00; voice_turn_valid = 0;
        check(2'b00, 1'b0, 2'b00, "T1:NONE");

        // T2: Button-only pass-through (left)
        btn_turn_req = 2'b01; btn_turn_valid = 1;
        voice_turn_req = 2'b00; voice_turn_valid = 0;
        check(2'b01, 1'b1, 2'b01, "T2:BTN_L");

        // T3: Button-only pass-through (right)
        btn_turn_req = 2'b10; btn_turn_valid = 1;
        voice_turn_req = 2'b00; voice_turn_valid = 0;
        check(2'b10, 1'b1, 2'b01, "T3:BTN_R");

        // T4: Voice-only pass-through (left)
        btn_turn_req = 2'b00; btn_turn_valid = 0;
        voice_turn_req = 2'b01; voice_turn_valid = 1;
        check(2'b01, 1'b1, 2'b10, "T4:VCE_L");

        // T5: Voice-only pass-through (right)
        btn_turn_req = 2'b00; btn_turn_valid = 0;
        voice_turn_req = 2'b10; voice_turn_valid = 1;
        check(2'b10, 1'b1, 2'b10, "T5:VCE_R");

        // T6: Simultaneous -> button wins
        btn_turn_req = 2'b01; btn_turn_valid = 1;
        voice_turn_req = 2'b10; voice_turn_valid = 1;
        check(2'b01, 1'b1, 2'b01, "T6:SIMUL");

        // T7: Simultaneous opposite -> button wins
        btn_turn_req = 2'b10; btn_turn_valid = 1;
        voice_turn_req = 2'b01; voice_turn_valid = 1;
        check(2'b10, 1'b1, 2'b01, "T7:SIMUL2");

        $display("---");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
