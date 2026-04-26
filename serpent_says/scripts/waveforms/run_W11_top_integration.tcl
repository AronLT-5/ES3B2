source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_top_serpent_says

wave_add /tb_top_serpent_says/CLK100MHZ
wave_add /tb_top_serpent_says/CPU_RESETN
wave_add /tb_top_serpent_says/clk_25mhz
wave_add /tb_top_serpent_says/btn_c_l_r binary
wave_add /tb_top_serpent_says/SW binary
wave_add /tb_top_serpent_says/fsm_state unsigned
wave_add /tb_top_serpent_says/game_tick
wave_add /tb_top_serpent_says/turn_req binary
wave_add /tb_top_serpent_says/turn_valid
wave_add /tb_top_serpent_says/p_head_x unsigned
wave_add /tb_top_serpent_says/p_head_y unsigned
wave_add /tb_top_serpent_says/VGA_HS
wave_add /tb_top_serpent_says/VGA_VS
wave_add /tb_top_serpent_says/vga_rgb hex
wave_add /tb_top_serpent_says/LED binary
wave_add /tb_top_serpent_says/AN binary
wave_add /tb_top_serpent_says/seg_ca_cg binary

run all
wave_finish_note "W11" "Compact view: btn_c_l_r={BTNC,BTNL,BTNR}, vga_rgb={VGA_R,VGA_G,VGA_B}, seg_ca_cg={CA,CB,CC,CD,CE,CF,CG}. Shows reset, start/play, movement, pause/resume, VGA, LED, seven-segment, and voice-mode status through SW/LED."
