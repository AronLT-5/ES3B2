source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_snake_game_core_w4

wave_add /tb_snake_game_core_w4/clk
wave_add /tb_snake_game_core_w4/reset_n
wave_add /tb_snake_game_core_w4/start_btn
wave_add /tb_snake_game_core_w4/pause_sw
wave_add /tb_snake_game_core_w4/game_tick
wave_add /tb_snake_game_core_w4/fsm_state unsigned
wave_add /tb_snake_game_core_w4/player_turn_valid
wave_add /tb_snake_game_core_w4/player_turn_req binary
wave_add /tb_snake_game_core_w4/pending_valid
wave_add /tb_snake_game_core_w4/pending_turn binary
wave_add /tb_snake_game_core_w4/pending_source binary
wave_add /tb_snake_game_core_w4/p_direction binary
wave_add /tb_snake_game_core_w4/p_head_x unsigned
wave_add /tb_snake_game_core_w4/p_head_y unsigned
wave_add /tb_snake_game_core_w4/p_length unsigned
wave_add /tb_snake_game_core_w4/p_lives unsigned
wave_add /tb_snake_game_core_w4/r_head_x unsigned
wave_add /tb_snake_game_core_w4/r_head_y unsigned
wave_add /tb_snake_game_core_w4/food_x unsigned
wave_add /tb_snake_game_core_w4/food_y unsigned
wave_add /tb_snake_game_core_w4/dbg_p_turn_accepted

run all
wave_finish_note "W4" "Shows reset/title/play transitions, a one-cycle turn latched between ticks, movement only on game_tick, and pause preventing movement."
