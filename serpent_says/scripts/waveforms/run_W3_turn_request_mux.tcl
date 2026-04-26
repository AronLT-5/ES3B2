source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_turn_request_mux

wave_add /tb_turn_request_mux/btn_turn_valid
wave_add /tb_turn_request_mux/btn_turn_req binary
wave_add /tb_turn_request_mux/voice_turn_valid
wave_add /tb_turn_request_mux/voice_turn_req binary
wave_add /tb_turn_request_mux/turn_valid
wave_add /tb_turn_request_mux/turn_req binary
wave_add /tb_turn_request_mux/turn_source binary

run all
wave_finish_note "W3" "Shows no input, button-only, voice-only, simultaneous, and conflicting simultaneous cases. Button priority is visible through turn_source=01."
