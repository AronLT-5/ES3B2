source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_clk_divider

wave_divider "W2 100 MHz to 25 MHz divider"
wave_add /tb_clk_divider/scenario ascii
wave_add /tb_clk_divider/CLK100MHZ
wave_add /tb_clk_divider/reset_n
wave_add /tb_clk_divider/dut/div_cnt binary
wave_add /tb_clk_divider/clk_25mhz
wave_add /tb_clk_divider/clk_out

run all
wave_finish_note "W2" "Shows div_cnt incrementing, clk_25mhz toggling from div_cnt[1], and reset returning the divider to zero."
