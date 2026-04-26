source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_info_bar_renderer

wave_add /tb_info_bar_renderer/clk
wave_add /tb_info_bar_renderer/reset_n
wave_add /tb_info_bar_renderer/pixel_x unsigned
wave_add /tb_info_bar_renderer/pixel_y unsigned
wave_add /tb_info_bar_renderer/video_active
wave_add /tb_info_bar_renderer/fsm_state unsigned
wave_add /tb_info_bar_renderer/p_length unsigned
wave_add /tb_info_bar_renderer/r_length unsigned
wave_add /tb_info_bar_renderer/p_lives unsigned
wave_add /tb_info_bar_renderer/r_lives unsigned
wave_add /tb_info_bar_renderer/voice_mode_en
wave_add /tb_info_bar_renderer/last_cmd binary
wave_add /tb_info_bar_renderer/turn_source binary
wave_add /tb_info_bar_renderer/glyph_char hex
wave_add /tb_info_bar_renderer/char_code hex
wave_add /tb_info_bar_renderer/life_icon_addr unsigned
wave_add /tb_info_bar_renderer/life_sprite_data hex
wave_add /tb_info_bar_renderer/info_active
wave_add /tb_info_bar_renderer/info_rgb hex

run all
wave_finish_note "W8" "Shows pixel_y < 100 info output, title/group-ID glyphs, dynamic lives/mode/source/command text, and life icon priority over text/background."
