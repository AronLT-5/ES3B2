source [file join [file dirname [file normalize [info script]]] "common_wave_setup.tcl"]

wave_launch tb_feature_pipeline_addr

wave_add /tb_feature_pipeline_addr/clk
wave_add /tb_feature_pipeline_addr/reset_n
wave_add /tb_feature_pipeline_addr/frame_ready
wave_add /tb_feature_pipeline_addr/fb_addr unsigned
wave_add /tb_feature_pipeline_addr/fb_addr_d unsigned
wave_add /tb_feature_pipeline_addr/fb_data decimal
wave_add /tb_feature_pipeline_addr/sample_valid
wave_add /tb_feature_pipeline_addr/fft_load_valid
wave_add /tb_feature_pipeline_addr/hann_coeff decimal
wave_add /tb_feature_pipeline_addr/windowed_sample decimal
wave_add /tb_feature_pipeline_addr/fft_start
wave_add /tb_feature_pipeline_addr/fft_done
wave_add /tb_feature_pipeline_addr/mel_start
wave_add /tb_feature_pipeline_addr/mel_valid
wave_add /tb_feature_pipeline_addr/mel_bin unsigned
wave_add /tb_feature_pipeline_addr/ctx_mel_in decimal
wave_add /tb_feature_pipeline_addr/ctx_frame_done
wave_add /tb_feature_pipeline_addr/busy

run all
wave_finish_note "W9" "Shows fb_data aligned with fb_addr_d, non-X Hann/windowed samples, FFT/Mel sequencing, and context writes completing."
