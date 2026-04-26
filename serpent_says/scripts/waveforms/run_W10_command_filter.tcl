source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_command_filter

wave_add /tb_command_filter/clk
wave_add /tb_command_filter/reset_n
wave_add /tb_command_filter/voice_mode_en
wave_add /tb_command_filter/kws_valid
wave_add /tb_command_filter/kws_class binary
wave_add /tb_command_filter/kws_conf decimal
wave_add /tb_command_filter/kws_second decimal
wave_add /tb_command_filter/conf_margin decimal
wave_add /tb_command_filter/cooldown_active
wave_add /tb_command_filter/cooldown_cnt unsigned
wave_add /tb_command_filter/voice_kws_valid
wave_add /tb_command_filter/voice_kws_class binary
wave_add /tb_command_filter/voice_turn_valid
wave_add /tb_command_filter/voice_turn_req binary
wave_add /tb_command_filter/last_cmd binary
wave_add /tb_command_filter/last_cmd_conf decimal
wave_add /tb_command_filter/ml_alive

run all
wave_finish_note "W10" "Shows voice disabled, accepted left/right, rejected other/low-confidence/low-margin cases, cooldown suppression, last_cmd, and ml_alive."
