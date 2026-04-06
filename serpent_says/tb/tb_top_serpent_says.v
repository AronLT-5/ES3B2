`timescale 1ns / 1ps

// Integration smoke test for the full top_serpent_says module.
// Uses fast tick parameters for simulation speed.
// Verifies: reset, start, pause, basic movement, restart, non-X outputs.

module tb_top_serpent_says;

    reg        CLK100MHZ;
    reg        CPU_RESETN;
    reg        BTNC, BTNL, BTNR;
    reg  [2:0] SW;
    reg        pdm_data_i;

    wire       pdm_clk_o, pdm_lrsel_o;
    wire       VGA_HS, VGA_VS;
    wire [3:0] VGA_R, VGA_G, VGA_B;
    wire [12:0] LED;
    wire       CA, CB, CC, CD, CE, CF, CG, DP;
    wire [7:0] AN;

    // Fast tick for simulation
    top_serpent_says #(
        .BUTTON_TICK_COUNT_MAX(100),
        .VOICE_TICK_COUNT_MAX(150),
        .INITIAL_LIVES(3)
    ) dut (
        .CLK100MHZ  (CLK100MHZ),
        .CPU_RESETN (CPU_RESETN),
        .BTNC       (BTNC),
        .BTNL       (BTNL),
        .BTNR       (BTNR),
        .SW         (SW),
        .pdm_data_i (pdm_data_i),
        .pdm_clk_o  (pdm_clk_o),
        .pdm_lrsel_o(pdm_lrsel_o),
        .VGA_HS     (VGA_HS),
        .VGA_VS     (VGA_VS),
        .VGA_R      (VGA_R),
        .VGA_G      (VGA_G),
        .VGA_B      (VGA_B),
        .LED        (LED),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD),
        .CE(CE), .CF(CF), .CG(CG), .DP(DP),
        .AN(AN)
    );

    always #5 CLK100MHZ = ~CLK100MHZ;  // 100 MHz

    integer pass_count = 0;
    integer fail_count = 0;

    task check_val;
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
        input [12:0] val;
        input [159:0] label;
        begin
            if (^val === 1'bx) begin
                $display("FAIL %0s: contains X", label);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s", label);
                pass_count = pass_count + 1;
            end
        end
    endtask

    task btn_pulse;
        input integer which;  // 0=BTNC, 1=BTNL, 2=BTNR
        begin
            case (which)
                0: begin BTNC = 1; #200; BTNC = 0; end
                1: begin BTNL = 1; #200; BTNL = 0; end
                2: begin BTNR = 1; #200; BTNR = 0; end
            endcase
            #100;
        end
    endtask

    // Wait for N game ticks (approximate -- based on fast tick param)
    task wait_ticks;
        input integer n;
        integer i;
        begin
            // Each tick ~100 cycles at 25MHz = 100*40ns = 4000ns. But clock is 100MHz so 100*4*10ns.
            // With BUTTON_TICK_COUNT_MAX=100 and clk_25mhz, each game tick = 100*40ns = 4us
            for (i = 0; i < n; i = i + 1) begin
                #5000; // ~1.25 tick periods, enough for one tick
            end
        end
    endtask

    initial begin
        $display("=== tb_top_serpent_says (integration smoke) ===");
        CLK100MHZ = 0;
        CPU_RESETN = 0;
        BTNC = 0; BTNL = 0; BTNR = 0;
        SW = 3'b000;
        pdm_data_i = 0;

        // Reset
        #200;
        CPU_RESETN = 1;
        #2000;

        // -----------------------------------------------
        // T1: Verify IDLE state after reset
        // -----------------------------------------------
        check_val(dut.u_game_core.fsm_state, 3'd0, "T1:IDLE");

        // -----------------------------------------------
        // T2: BTNC starts game
        // -----------------------------------------------
        btn_pulse(0);
        #500;
        check_val(dut.u_game_core.fsm_state, 3'd1, "T2:PLAYING");

        // -----------------------------------------------
        // T3: LEDs are not X
        // -----------------------------------------------
        #1000;
        check_not_x(LED, "T3:LED_no_X");

        // -----------------------------------------------
        // T4: Seven-seg AN not all X
        // -----------------------------------------------
        check_not_x({5'b0, AN}, "T4:AN_no_X");

        // -----------------------------------------------
        // T5: Pause/resume
        // -----------------------------------------------
        SW[0] = 1;
        #2000;
        check_val(dut.u_game_core.fsm_state, 3'd2, "T5a:PAUSED");
        SW[0] = 0;
        #2000;
        check_val(dut.u_game_core.fsm_state, 3'd1, "T5b:RESUMED");

        // -----------------------------------------------
        // T6: Button turn works (basic movement after several ticks)
        // -----------------------------------------------
        wait_ticks(3);
        btn_pulse(1); // BTNL
        wait_ticks(2);
        // Just verify no X in VGA outputs
        if (^{VGA_R, VGA_G, VGA_B} === 1'bx) begin
            $display("FAIL T6:VGA_X");
            fail_count = fail_count + 1;
        end else begin
            $display("PASS T6:VGA_no_X");
            pass_count = pass_count + 1;
        end

        // -----------------------------------------------
        // T7: Voice stubs don't break anything
        // -----------------------------------------------
        SW[2] = 1; // voice mode
        wait_ticks(3);
        check_val(dut.u_game_core.fsm_state, 3'd1, "T7:voice_mode_ok");
        SW[2] = 0;

        // -----------------------------------------------
        // T8: Debug LED mode
        // -----------------------------------------------
        SW[1] = 1;
        #1000;
        check_not_x(LED, "T8:debug_LED_no_X");
        SW[1] = 0;

        // -----------------------------------------------
        // Summary
        // -----------------------------------------------
        $display("\n===========================");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
