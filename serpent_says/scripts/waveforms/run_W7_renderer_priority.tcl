source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_pixel_renderer_priority

wave_add /tb_pixel_renderer_priority/clk
wave_add /tb_pixel_renderer_priority/pixel_x unsigned
wave_add /tb_pixel_renderer_priority/pixel_y unsigned
wave_add /tb_pixel_renderer_priority/video_active
wave_add /tb_pixel_renderer_priority/info_active
wave_add /tb_pixel_renderer_priority/tile_x unsigned
wave_add /tb_pixel_renderer_priority/tile_y unsigned
wave_add /tb_pixel_renderer_priority/player_head_hit
wave_add /tb_pixel_renderer_priority/player_body_hit
wave_add /tb_pixel_renderer_priority/food_hit
wave_add /tb_pixel_renderer_priority/obstacle_hit
wave_add /tb_pixel_renderer_priority/border_hit
wave_add /tb_pixel_renderer_priority/sprite_rgb hex
wave_add /tb_pixel_renderer_priority/info_rgb hex
wave_add /tb_pixel_renderer_priority/final_rgb hex
wave_add /tb_pixel_renderer_priority/VGA_R hex
wave_add /tb_pixel_renderer_priority/VGA_G hex
wave_add /tb_pixel_renderer_priority/VGA_B hex
wave_add /tb_pixel_renderer_priority/fsm_state unsigned
wave_add /tb_pixel_renderer_priority/gameover_sprite_data hex

run all
wave_finish_note "W7" "Shows inactive black, info override, player head priority, transparent sprite fall-through, food/obstacle pixels, border, and terminal overlay priority."
