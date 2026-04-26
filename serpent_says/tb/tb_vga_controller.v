`timescale 1ns / 1ps

module tb_vga_controller;

    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    localparam H_VISIBLE_END = 639;
    localparam H_FRONT_START = 640;
    localparam H_SYNC_START  = 656;
    localparam H_BACK_START  = 752;

    localparam V_SYNC_START  = 490;
    localparam V_BACK_START  = 492;

    reg clk_25mhz;
    reg reset_n;

    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       hsync;
    wire       vsync;
    wire       VGA_HS;
    wire       VGA_VS;
    wire       video_active;

    wire in_visible_area;
    wire info_bar_region;
    wire h_front_porch;
    wire h_sync_region;
    wire h_back_porch;
    wire v_sync_region;
    wire v_back_porch;

    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    assign in_visible_area = video_active;
    assign info_bar_region = video_active && (pixel_y < 10'd100);
    assign h_front_porch   = (pixel_x >= H_FRONT_START) && (pixel_x < H_SYNC_START);
    assign h_sync_region   = (pixel_x >= H_SYNC_START)  && (pixel_x < H_BACK_START);
    assign h_back_porch    = (pixel_x >= H_BACK_START)  && (pixel_x < H_TOTAL);
    assign v_sync_region   = (pixel_y >= V_SYNC_START)  && (pixel_y < V_BACK_START);
    assign v_back_porch    = (pixel_y >= V_BACK_START)  && (pixel_y < V_TOTAL);

    vga_controller dut (
        .clk_pix      (clk_25mhz),
        .reset_n      (reset_n),
        .pixel_x      (pixel_x),
        .pixel_y      (pixel_y),
        .hsync        (hsync),
        .vsync        (vsync),
        .video_active (video_active)
    );

    always #20 clk_25mhz = ~clk_25mhz;

    integer pass_count;
    integer fail_count;

    task check;
        input condition;
        input [159:0] label;
        begin
            if (!condition) begin
                $display("FAIL %0s at %0t: x=%0d y=%0d active=%0b hsync=%0b vsync=%0b",
                    label, $time, pixel_x, pixel_y, video_active, hsync, vsync);
                fail_count = fail_count + 1;
            end else begin
                $display("PASS %0s at %0t: x=%0d y=%0d active=%0b hsync=%0b vsync=%0b",
                    label, $time, pixel_x, pixel_y, video_active, hsync, vsync);
                pass_count = pass_count + 1;
            end
        end
    endtask

    initial begin
`ifdef DUMP_VCD
        $dumpfile("tb_vga_controller.vcd");
        $dumpvars(0, tb_vga_controller);
`endif
    end

    initial begin
        $display("=== W1 tb_vga_controller ===");

        clk_25mhz = 1'b0;
        reset_n = 1'b0;
        pass_count = 0;
        fail_count = 0;

        repeat (5) @(posedge clk_25mhz);
        #1;
        check(pixel_x == 10'd0 && pixel_y == 10'd0 && video_active == 1'b0 &&
              hsync == 1'b1 && vsync == 1'b1, "reset_known_state");

        reset_n = 1'b1;

        wait (pixel_x == 10'd10 && pixel_y == 10'd0);
        #1;
        check(video_active == 1'b1 && in_visible_area == 1'b1, "visible_region_active");

        wait (pixel_x == H_VISIBLE_END && pixel_y == 10'd0);
        #1;
        check(video_active == 1'b1, "last_visible_pixel_active");

        wait (pixel_x == H_FRONT_START && pixel_y == 10'd0);
        #1;
        check(video_active == 1'b0 && h_front_porch == 1'b1, "front_porch_inactive");

        wait (pixel_x == H_SYNC_START && pixel_y == 10'd0);
        #1;
        check(hsync == 1'b0 && h_sync_region == 1'b1, "hsync_low_after_front_porch");

        wait (pixel_x == H_BACK_START && pixel_y == 10'd0);
        #1;
        check(hsync == 1'b1 && h_back_porch == 1'b1, "hsync_returns_high_after_sync");

        wait (pixel_x == 10'd0 && pixel_y == 10'd1);
        #1;
        check(video_active == 1'b1, "pixel_y_incremented_at_wrap");

        if ($test$plusargs("WAVE_STOPS")) begin
            $display("WAVE_STOPS: horizontal timing window complete at %0t", $time);
            $stop;
        end

        wait (pixel_x == 10'd0 && pixel_y == V_SYNC_START);
        #1;
        check(vsync == 1'b0 && v_sync_region == 1'b1, "vsync_low_in_vertical_sync");

        wait (pixel_x == 10'd0 && pixel_y == V_BACK_START);
        #1;
        check(vsync == 1'b1 && v_back_porch == 1'b1, "vsync_returns_high");

        wait (pixel_x == 10'd0 && pixel_y == 10'd0);
        #1;
        check(video_active == 1'b1, "new_frame_visible_again");

        if ($test$plusargs("WAVE_STOPS")) begin
            $display("WAVE_STOPS: vertical timing/frame boundary complete at %0t", $time);
            $stop;
        end

        $display("W1 Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("W1 ALL TESTS PASSED");
            $finish;
        end else begin
            $display("W1 SOME TESTS FAILED");
            $fatal;
        end
    end

endmodule
