`timescale 1ns / 1ps

module tb_turn_request_mux;

    reg  [1:0] btn_turn_req;
    reg        btn_turn_valid;
    reg  [1:0] voice_turn_req;
    reg        voice_turn_valid;

    wire [1:0] player_turn_req;
    wire       player_turn_valid;
    wire [1:0] turn_req;
    wire       turn_valid;
    wire [1:0] turn_source;

    assign turn_req   = player_turn_req;
    assign turn_valid = player_turn_valid;

    turn_request_mux dut (
        .btn_turn_req     (btn_turn_req),
        .btn_turn_valid   (btn_turn_valid),
        .voice_turn_req   (voice_turn_req),
        .voice_turn_valid (voice_turn_valid),
        .player_turn_req  (player_turn_req),
        .player_turn_valid(player_turn_valid),
        .turn_source      (turn_source)
    );

    integer pass_count;
    integer fail_count;

    task drive_case;
        input [127:0] name;
        input [1:0]   b_req;
        input         b_valid;
        input [1:0]   v_req;
        input         v_valid;
        input [1:0]   exp_req;
        input         exp_valid;
        input [1:0]   exp_source;
        begin
            btn_turn_req = b_req;
            btn_turn_valid = b_valid;
            voice_turn_req = v_req;
            voice_turn_valid = v_valid;
            #10;
            if (turn_req !== exp_req || turn_valid !== exp_valid || turn_source !== exp_source) begin
                $display("FAIL %0s: btn_valid=%b btn_req=%b voice_valid=%b voice_req=%b -> req=%b valid=%b source=%b expected req=%b valid=%b source=%b",
                    name, btn_turn_valid, btn_turn_req, voice_turn_valid, voice_turn_req,
                    turn_req, turn_valid, turn_source, exp_req, exp_valid, exp_source);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s: btn_valid=%b btn_req=%b voice_valid=%b voice_req=%b -> req=%b valid=%b source=%b",
                    name, btn_turn_valid, btn_turn_req, voice_turn_valid, voice_turn_req,
                    turn_req, turn_valid, turn_source);
                pass_count = pass_count + 1;
            end
            #30;
        end
    endtask

    initial begin
`ifdef DUMP_VCD
        $dumpfile("tb_turn_request_mux.vcd");
        $dumpvars(0, tb_turn_request_mux);
`endif
    end

    initial begin
        $display("=== W3 tb_turn_request_mux ===");
        pass_count = 0;
        fail_count = 0;
        btn_turn_req = 2'b00;
        btn_turn_valid = 1'b0;
        voice_turn_req = 2'b00;
        voice_turn_valid = 1'b0;
        #20;

        drive_case("no_input",       2'b00, 1'b0, 2'b00, 1'b0, 2'b00, 1'b0, 2'b00);
        drive_case("button_left",    2'b01, 1'b1, 2'b00, 1'b0, 2'b01, 1'b1, 2'b01);
        drive_case("button_right",   2'b10, 1'b1, 2'b00, 1'b0, 2'b10, 1'b1, 2'b01);
        drive_case("voice_left",     2'b00, 1'b0, 2'b01, 1'b1, 2'b01, 1'b1, 2'b10);
        drive_case("voice_right",    2'b00, 1'b0, 2'b10, 1'b1, 2'b10, 1'b1, 2'b10);
        drive_case("simul_same",     2'b01, 1'b1, 2'b01, 1'b1, 2'b01, 1'b1, 2'b01);
        drive_case("simul_conflict", 2'b10, 1'b1, 2'b01, 1'b1, 2'b10, 1'b1, 2'b01);

        $display("W3 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("W3 ALL TESTS PASSED");
            $finish;
        end else begin
            $display("W3 SOME TESTS FAILED");
            $fatal;
        end
    end

endmodule
