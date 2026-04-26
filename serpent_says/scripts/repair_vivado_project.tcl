# Run from Vivado with:
#   Tools > Run Tcl Script...
# or:
#   vivado -mode batch -source serpent_says/scripts/repair_vivado_project.tcl
#
# This script is intentionally idempotent. It can repair the checked-in
# serpent_says.xpr, or populate an empty Vivado project with the canonical RTL,
# constraints, memory initialization files, and simulation testbenches.

set script_path [info script]
if {[file pathtype $script_path] eq "relative"} {
    set script_path [file join [pwd] $script_path]
}
set script_dir  [file dirname $script_path]
set project_dir [file dirname $script_dir]
set project_name "serpent_says"
set project_part "xc7a100tcsg324-1"
set xpr_file [file join $project_dir "${project_name}.xpr"]

set rtl_dir    [file join $project_dir "rtl"]
set tb_dir     [file join $project_dir "tb"]
set mem_dir    [file join $project_dir "Sprites" "mem"]
set xdc_dir    [file join $project_dir "xdc"]
set top_xdc    [file join $xdc_dir "top.xdc"]
set top_module "top_serpent_says"
set sim_top    "tb_top_serpent_says"

proc canonical_path {path} {
    return [string tolower [string map {\\ /} [file nativename $path]]]
}

proc ensure_fileset {name kind} {
    set fs [get_filesets -quiet $name]
    if {[llength $fs] == 0} {
        switch -- $kind {
            src    { create_fileset -srcset $name }
            sim    { create_fileset -simset $name }
            constr { create_fileset -constrset $name }
            default { error "Unknown fileset kind '$kind'" }
        }
        set fs [get_filesets -quiet $name]
    }

    if {[llength $fs] == 0} {
        error "Could not create or find fileset '$name'"
    }
    return $fs
}

proc add_missing_files {fileset files} {
    set existing {}
    foreach f [get_files -quiet -of_objects $fileset] {
        lappend existing [canonical_path $f]
    }

    foreach f $files {
        if {![file exists $f]} {
            puts "WARNING: skipping missing file: $f"
            continue
        }

        set key [canonical_path $f]
        if {[lsearch -exact $existing $key] < 0} {
            add_files -fileset $fileset -norecurse [file nativename $f]
            lappend existing $key
        }
    }
}

proc set_file_property_quiet {files prop value} {
    foreach f $files {
        set objs [get_files -quiet [file nativename $f]]
        if {[llength $objs] > 0} {
            catch {set_property $prop $value $objs}
        }
    }
}

if {[catch {current_project}]} {
    if {[file exists $xpr_file]} {
        open_project $xpr_file
    } else {
        create_project $project_name $project_dir -part $project_part -force
    }
}

catch {set_property part $project_part [current_project]}
catch {set_property target_language Verilog [current_project]}
catch {set_property simulator_language Mixed [current_project]}
catch {set_property source_mgmt_mode All [current_project]}

set srcset    [ensure_fileset sources_1 src]
set simset    [ensure_fileset sim_1 sim]
set constrset [ensure_fileset constrs_1 constr]

catch {current_fileset -srcset $srcset}
catch {current_fileset -simset $simset}
catch {current_fileset -constrset $constrset}

# Remove stale generated artifacts AND any fileset entry whose underlying
# file no longer exists on disk (e.g. sprites that were renamed/deleted).
# Without this, synthesis fails with "File '...' does not exist".
foreach fs [get_filesets -quiet *] {
    set remove_list {}
    foreach f [get_files -quiet -of_objects $fs] {
        set p [canonical_path $f]
        if {[string match */utils_1/imports/synth_1/top_serpent_says.dcp $p]} {
            lappend remove_list $f
            continue
        }
        if {[string match */serpent_says.srcs/sources_1/new/top_serpent_says.v $p]} {
            lappend remove_list $f
            continue
        }
        if {[string match */serpent_says.srcs/sources_1/new/clk_divider.v $p]} {
            lappend remove_list $f
            continue
        }
        if {![file exists $f]} {
            lappend remove_list $f
        }
    }
    if {[llength $remove_list] > 0} {
        puts "Pruning [llength $remove_list] stale entries from [get_property NAME $fs]:"
        foreach f $remove_list { puts "  $f" }
        remove_files -fileset $fs $remove_list
    }
}

# Canonical project contents.
set rtl_files [lsort [glob -nocomplain [file join $rtl_dir "*.v"]]]
set vh_files  [lsort [glob -nocomplain [file join $rtl_dir "*.vh"]]]
set mem_files [lsort [glob -nocomplain [file join $mem_dir "*.mem"]]]
set tb_files  [lsort [glob -nocomplain [file join $tb_dir "*.v"]]]

add_missing_files $srcset $rtl_files
add_missing_files $srcset $vh_files
add_missing_files $srcset $mem_files
add_missing_files $constrset [list $top_xdc]

# Simulation needs the testbenches and the same memory init files used by
# $readmemh. Keeping the memory files in sim_1 makes XSim copy/resolve them
# consistently when launching individual testbenches.
add_missing_files $simset $tb_files
add_missing_files $simset $mem_files

set_file_property_quiet $vh_files file_type {Verilog Header}
set_file_property_quiet $mem_files file_type {Memory File}
set_file_property_quiet $tb_files used_in_synthesis false
set_file_property_quiet $tb_files used_in_simulation true
set_file_property_quiet $rtl_files used_in_synthesis true
set_file_property_quiet $rtl_files used_in_simulation true
set_file_property_quiet $vh_files used_in_synthesis true
set_file_property_quiet $vh_files used_in_simulation true
set_file_property_quiet $mem_files used_in_synthesis true
set_file_property_quiet $mem_files used_in_simulation true

set_property include_dirs [list $rtl_dir] $srcset
set_property include_dirs [list $rtl_dir] $simset
set_property top $top_module $srcset
if {[file exists [file join $tb_dir "${sim_top}.v"]]} {
    set_property top $sim_top $simset
}

if {[file exists $top_xdc]} {
    catch {set_property target_constrs_file [file nativename $top_xdc] $constrset}
}

# Disable stale incremental checkpoint configuration. Synthesis uses the
# synth_design incremental_mode option; implementation uses run properties.
if {[llength [get_runs -quiet synth_1]] > 0} {
    set synth_run [get_runs synth_1]
    catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 $synth_run}
    catch {set_property INCREMENTAL_CHECKPOINT "" $synth_run}
    catch {reset_property INCREMENTAL_CHECKPOINT $synth_run}
    catch {set_property STEPS.SYNTH_DESIGN.ARGS.INCREMENTAL_MODE off $synth_run}
}

if {[llength [get_runs -quiet impl_1]] > 0} {
    set impl_run [get_runs impl_1]
    catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 $impl_run}
    catch {set_property INCREMENTAL_CHECKPOINT "" $impl_run}
    catch {reset_property INCREMENTAL_CHECKPOINT $impl_run}
}

update_compile_order -fileset sources_1
catch {update_compile_order -fileset sim_1}

catch {reset_run synth_1}
catch {reset_run impl_1}

puts "Vivado project setup complete."
puts "  Project directory : $project_dir"
puts "  Part              : $project_part"
puts "  Design top        : $top_module"
puts "  Simulation top    : $sim_top"
puts "  RTL files         : [llength $rtl_files]"
puts "  Include files     : [llength $vh_files]"
puts "  Memory files      : [llength $mem_files]"
puts "  Testbenches       : [llength $tb_files]"
puts "  Constraint file   : $top_xdc"
puts "Use Generate Bitstream to build top_serpent_says."
