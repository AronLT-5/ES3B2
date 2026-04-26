source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_snake_game_core_w6

wave_add /tb_snake_game_core_w6/clk
wave_add /tb_snake_game_core_w6/reset_n
wave_add /tb_snake_game_core_w6/game_tick
wave_add /tb_snake_game_core_w6/fsm_state unsigned
wave_add /tb_snake_game_core_w6/p_head_x unsigned
wave_add /tb_snake_game_core_w6/p_head_y unsigned
wave_add /tb_snake_game_core_w6/food_x unsigned
wave_add /tb_snake_game_core_w6/food_y unsigned
wave_add /tb_snake_game_core_w6/food_idx unsigned
wave_add /tb_snake_game_core_w6/dbg_p_ate
wave_add /tb_snake_game_core_w6/anim_food_eaten
wave_add /tb_snake_game_core_w6/p_length unsigned
wave_add /tb_snake_game_core_w6/p_score_proxy
wave_add /tb_snake_game_core_w6/r_length unsigned

run all
wave_finish_note "W6" "Shows player head entering food, dbg_p_ate/anim_food_eaten pulsing, p_length increasing, and food_idx/food location moving to a new candidate."
