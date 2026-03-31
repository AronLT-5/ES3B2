`timescale 1ns / 1ps

module vga_controller (
    input  wire       clk_pix,
    input  wire       reset_n,
    output reg [9:0]  pixel_x,
    output reg [9:0]  pixel_y,
    output reg        hsync,
    output reg        vsync,
    output reg        video_active
);

    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk_pix or negedge reset_n) begin
        if (!reset_n) begin
            h_count      <= 10'd0;
            v_count      <= 10'd0;
            pixel_x      <= 10'd0;
            pixel_y      <= 10'd0;
            hsync        <= 1'b1;
            vsync        <= 1'b1;
            video_active <= 1'b0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end

            pixel_x <= h_count;
            pixel_y <= v_count;

            video_active <= (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

            hsync <= ~((h_count >= H_VISIBLE + H_FRONT) &&
                       (h_count <  H_VISIBLE + H_FRONT + H_SYNC));

            vsync <= ~((v_count >= V_VISIBLE + V_FRONT) &&
                       (v_count <  V_VISIBLE + V_FRONT + V_SYNC));
        end
    end

endmodule