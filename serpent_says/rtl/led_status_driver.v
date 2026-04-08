`timescale 1ns / 1ps

module led_status_driver (
    input  wire        debug_mode,        // SW[1]
    input  wire        voice_ready,       // SW[2] (stub)
    input  wire [2:0]  fsm_state,
    input  wire [1:0]  p_lives,
    input  wire [1:0]  r_lives,
    input  wire [1:0]  p_direction,
    input  wire [1:0]  r_direction,
    input  wire        dbg_p_turn_accepted,
    input  wire        dbg_r_dir_changed,
    input  wire        dbg_p_collision,
    input  wire        dbg_r_collision,
    input  wire        dbg_p_ate,
    input  wire        dbg_r_ate,
    input  wire        voice_active,      // stretched ~0.25s pulse on accepted voice turn
    output wire [12:0] led
);

    localparam IDLE      = 3'd0;
    localparam PLAYING   = 3'd1;
    localparam PAUSED    = 3'd2;
    localparam VICTORY   = 3'd3;
    localparam GAME_OVER = 3'd4;

    // Normal mode lives bitmap: lives=3 -> 111, lives=2 -> 011, lives=1 -> 001, lives=0 -> 000
    wire [2:0] p_lives_bmp = (p_lives == 2'd3) ? 3'b111 :
                             (p_lives == 2'd2) ? 3'b011 :
                             (p_lives == 2'd1) ? 3'b001 :
                                                  3'b000;
    wire [2:0] r_lives_bmp = (r_lives == 2'd3) ? 3'b111 :
                             (r_lives == 2'd2) ? 3'b011 :
                             (r_lives == 2'd1) ? 3'b001 :
                                                  3'b000;

    wire is_paused   = (fsm_state == PAUSED);
    wire is_terminal = (fsm_state == VICTORY) || (fsm_state == GAME_OVER);

    wire [12:0] normal_led = {
        3'b000,               // LED[12:10]
        voice_active,         // LED[9]  accepted voice command indicator
        voice_ready,          // LED[8]  voice mode enabled (SW[2])
        is_terminal,          // LED[7]
        is_paused,            // LED[6]
        r_lives_bmp,          // LED[5:3]
        p_lives_bmp           // LED[2:0]
    };

    wire [12:0] debug_led = {
        fsm_state,            // LED[12:10]
        dbg_r_ate,            // LED[9]
        dbg_p_ate,            // LED[8]
        dbg_r_collision,      // LED[7]
        dbg_p_collision,      // LED[6]
        dbg_r_dir_changed,    // LED[5]
        dbg_p_turn_accepted,  // LED[4]
        r_direction,          // LED[3:2]
        p_direction           // LED[1:0]
    };

    assign led = debug_mode ? debug_led : normal_led;

endmodule
