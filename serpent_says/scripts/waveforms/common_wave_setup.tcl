# Common helpers for Serpent Says waveform-evidence simulations.

set wave_script_dir [file dirname [file normalize [info script]]]
set wave_project_dir [file normalize [file join $wave_script_dir ".." ".."]]
set wave_xpr_file [file join $wave_project_dir "serpent_says.xpr"]
set wave_rtl_dir [file join $wave_project_dir "rtl"]
set wave_tb_dir [file join $wave_project_dir "tb"]
set wave_mem_dir [file join $wave_project_dir "Sprites" "mem"]

proc wave_open_project {} {
    global wave_xpr_file
    if {[catch {current_project}]} {
        open_project $wave_xpr_file
    }
}

proc wave_add_missing_files {fileset files} {
    set existing {}
    foreach f [get_files -quiet -of_objects $fileset] {
        lappend existing [string map {\\ /} [file normalize $f]]
    }

    foreach f $files {
        set normalized [file normalize $f]
        set key [string map {\\ /} $normalized]
        if {[lsearch -exact $existing $key] < 0} {
            add_files -fileset $fileset -norecurse $normalized
            lappend existing $key
        }
    }
}

proc wave_refresh_project {} {
    global wave_project_dir wave_rtl_dir wave_tb_dir wave_mem_dir

    wave_open_project

    set srcset [get_filesets sources_1]
    set simset [get_filesets sim_1]

    wave_add_missing_files $srcset [glob -nocomplain [file join $wave_rtl_dir *.v]]
    wave_add_missing_files $srcset [glob -nocomplain [file join $wave_rtl_dir *.vh]]
    wave_add_missing_files $srcset [glob -nocomplain [file join $wave_mem_dir *.mem]]
    wave_add_missing_files $simset [glob -nocomplain [file join $wave_tb_dir *.v]]
    wave_add_missing_files $simset [glob -nocomplain [file join $wave_mem_dir *.mem]]

    foreach f [get_files -quiet [file join $wave_mem_dir *.mem]] {
        catch {set_property file_type {Memory File} $f}
    }

    foreach f [get_files -quiet -of_objects $simset] {
        catch {set_property IS_ENABLED true $f}
    }

    set_property include_dirs [list $wave_rtl_dir] $srcset
    catch {set_property include_dirs [list $wave_rtl_dir] $simset}
    set_property top top_serpent_says $srcset

    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
}

proc wave_launch {top_module} {
    global wave_mem_dir

    wave_refresh_project
    catch {close_sim}
    set simset [get_filesets sim_1]
    set_property top $top_module $simset
    update_compile_order -fileset sim_1

    cd $wave_mem_dir
    launch_simulation -simset sim_1 -mode behavioral
    catch {remove_wave -quiet [get_waves *]}
    catch {restart}
}

proc wave_add {path {radix ""}} {
    if {$radix eq ""} {
        if {[catch {add_wave -quiet $path} msg]} {
            puts "WARN: could not add wave $path: $msg"
        }
    } else {
        if {[catch {add_wave -quiet -radix $radix $path} msg]} {
            puts "WARN: could not add wave $path: $msg"
        }
    }
}

proc wave_divider {name} {
    catch {add_wave_divider $name}
}

proc wave_finish_note {label note} {
    puts ""
    puts "============================================================"
    puts "$label waveform capture ready."
    puts "$note"
    puts "Record or screenshot the waveform, then source the next W script."
    puts "============================================================"
}
