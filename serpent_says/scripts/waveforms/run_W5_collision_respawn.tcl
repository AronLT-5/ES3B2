source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_snake_game_core_w5

wave_add /tb_snake_game_core_w5/clk
wave_add /tb_snake_game_core_w5/reset_n
wave_add /tb_snake_game_core_w5/game_tick
wave_add /tb_snake_game_core_w5/fsm_state unsigned
wave_add /tb_snake_game_core_w5/p_head_x unsigned
wave_add /tb_snake_game_core_w5/p_head_y unsigned
wave_add /tb_snake_game_core_w5/p_direction binary
wave_add /tb_snake_game_core_w5/p_collision
wave_add /tb_snake_game_core_w5/dbg_p_collision
wave_add /tb_snake_game_core_w5/p_lives unsigned
wave_add /tb_snake_game_core_w5/p_dying
wave_add /tb_snake_game_core_w5/anim_p_dying
wave_add /tb_snake_game_core_w5/respawn_timer unsigned
wave_add /tb_snake_game_core_w5/r_lives unsigned
wave_add /tb_snake_game_core_w5/game_over
wave_add /tb_snake_game_core_w5/p_length unsigned

run all
wave_finish_note "W5" "Shows wall collision pulse, life decrement, RESPAWNING with timer/dying animation, restored spawn state, and last-life GAME_OVER."
