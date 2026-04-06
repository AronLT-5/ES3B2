`timescale 1ns / 1ps

module turn_request_mux (
    input  wire [1:0] btn_turn_req,
    input  wire       btn_turn_valid,
    input  wire [1:0] voice_turn_req,
    input  wire       voice_turn_valid,
    output wire [1:0] player_turn_req,
    output wire       player_turn_valid,
    output wire [1:0] turn_source        // 00=none, 01=button, 10=voice
);

    // Button overrides voice if both valid simultaneously
    assign player_turn_valid = btn_turn_valid | voice_turn_valid;

    assign player_turn_req = btn_turn_valid   ? btn_turn_req   :
                             voice_turn_valid ? voice_turn_req  :
                                                2'b00;

    assign turn_source = btn_turn_valid   ? 2'b01 :
                         voice_turn_valid ? 2'b10 :
                                            2'b00;

endmodule
