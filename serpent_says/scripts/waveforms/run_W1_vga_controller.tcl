source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_vga_controller

wave_divider "W1 VGA timing and coordinates"
wave_add /tb_vga_controller/scenario ascii
wave_add /tb_vga_controller/clk_25mhz
wave_add /tb_vga_controller/reset_n
wave_add /tb_vga_controller/pixel_x unsigned
wave_add /tb_vga_controller/pixel_y unsigned
wave_add /tb_vga_controller/video_active
wave_add /tb_vga_controller/VGA_HS
wave_add /tb_vga_controller/VGA_VS
wave_add /tb_vga_controller/dut/h_count unsigned
wave_add /tb_vga_controller/dut/v_count unsigned

run all
wave_finish_note "W1" "Shows pixel_x counting across visible and porch periods, video_active only during visible pixels, hsync after front porch, pixel_y line wrap, and a frame boundary."
