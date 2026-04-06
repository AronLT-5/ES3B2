`timescale 1ns / 1ps

module button_input_adapter (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       btnl_raw,
    input  wire       btnr_raw,
    input  wire       btnc_raw,
    output wire [1:0] turn_req,
    output wire       turn_valid,
    output wire       start_btn
);

    // 2-stage synchronisers
    reg btnl_s1, btnl_s2, btnr_s1, btnr_s2, btnc_s1, btnc_s2;
    reg btnl_prev, btnr_prev, btnc_prev;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            {btnl_s1, btnl_s2} <= 2'b00;
            {btnr_s1, btnr_s2} <= 2'b00;
            {btnc_s1, btnc_s2} <= 2'b00;
            btnl_prev <= 1'b0;
            btnr_prev <= 1'b0;
            btnc_prev <= 1'b0;
        end else begin
            btnl_s1 <= btnl_raw;  btnl_s2 <= btnl_s1;
            btnr_s1 <= btnr_raw;  btnr_s2 <= btnr_s1;
            btnc_s1 <= btnc_raw;  btnc_s2 <= btnc_s1;
            btnl_prev <= btnl_s2;
            btnr_prev <= btnr_s2;
            btnc_prev <= btnc_s2;
        end
    end

    wire btnl_rise = btnl_s2 & ~btnl_prev;
    wire btnr_rise = btnr_s2 & ~btnr_prev;
    wire btnc_rise = btnc_s2 & ~btnc_prev;

    // One-cycle turn events: left priority
    assign turn_valid = btnl_rise | btnr_rise;
    assign turn_req   = btnl_rise ? 2'b01 :
                        btnr_rise ? 2'b10 :
                                    2'b00;
    assign start_btn  = btnc_rise;

endmodule
