`timescale 1ns / 1ps

module game_tick_gen #(
    parameter BUTTON_TICK_MAX = 12_500_000,
    parameter VOICE_TICK_MAX  = 18_750_000
)(
    input  wire clk,
    input  wire reset_n,
    input  wire enable,
    input  wire voice_mode_en,
    output wire game_tick
);

    reg [31:0] tick_counter;
    reg        voice_mode_prev;

    wire [31:0] tick_max = voice_mode_en ? VOICE_TICK_MAX - 1 : BUTTON_TICK_MAX - 1;
    wire        mode_changed = (voice_mode_en != voice_mode_prev);

    assign game_tick = enable && (tick_counter == tick_max);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tick_counter   <= 32'd0;
            voice_mode_prev <= 1'b0;
        end else begin
            voice_mode_prev <= voice_mode_en;
            if (!enable || mode_changed || game_tick)
                tick_counter <= 32'd0;
            else
                tick_counter <= tick_counter + 32'd1;
        end
    end

endmodule
