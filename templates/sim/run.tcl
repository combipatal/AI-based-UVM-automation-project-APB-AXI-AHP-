# Tcl script to run simulation in Vivado (Project-less flow)
# Run with: vivado -mode batch -source run.tcl

#=============================================================================
# PROCEDURE: save_report - saves simulation log to report directory
#=============================================================================
proc save_report {log_file report_dir timestamp protocol} {
    if {[file exists $log_file]} {
        set dest_log [file join $report_dir $log_file]
        file copy -force $log_file $dest_log
        
        set summary_file [file join $report_dir "summary_$timestamp.txt"]
        set fp [open $summary_file w]
        puts $fp "=== UVM [string toupper $protocol] Simulation Summary ==="
        puts $fp "Timestamp: $timestamp"
        puts $fp "Log File: $log_file"
        puts $fp ""
        
        if {[catch {
            set log_content [open $log_file r]
            set in_summary 0
            while {[gets $log_content line] >= 0} {
                if {[string match "*UVM Report Summary*" $line]} {
                    set in_summary 1
                }
                if {$in_summary} {
                    puts $fp $line
                }
            }
            close $log_content
        } err]} {
            puts $fp "Error reading log: $err"
        }
        close $fp
        
        puts "\n========================================="
        puts "  Simulation Complete"
        puts "========================================="
        puts "Log:     $dest_log"
        puts "Summary: $summary_file"
        puts "=========================================\n"
    } else {
        puts "ERROR: Log file not found: $log_file"
    }
}

#=============================================================================
# PROCEDURE: run_simulation - main simulation flow
#=============================================================================
proc run_simulation {} {
    # === Setup Report Directory ===
    set base_dir [file dirname [file dirname [pwd]]]
    set report_dir [file join $base_dir "report"]
    
    if {![file exists $report_dir]} {
        file mkdir $report_dir
    }
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d_%H%M%S"]
    set log_file "simulation_$timestamp.log"
    
    puts "### \[0/3\] Compiling C Wrapper (gcc -> dll) ###"
    
    # Clean up previous build artifacts
    file delete -force "xsim.dir"
    file delete -force "dpi.dll" "apb_dpi.dll" "libdpi.dll"
    
    # Find GCC in Vivado installation
    set vivado_dir $::env(XILINX_VIVADO)
    set gcc_glob [glob -nocomplain -directory "$vivado_dir/tps/mingw" "*"]
    if {$gcc_glob eq ""} {
        puts "Error: Could not find MinGW in $vivado_dir/tps/mingw"
        return
    }
    set mingw_dir [lindex $gcc_glob 0]
    set gcc_exe "$mingw_dir/win64.o/nt/bin/gcc.exe"
    
    if {![file exists $gcc_exe]} {
        puts "Error: GCC not found at $gcc_exe"
        return
    }
    
    puts "Using GCC: $gcc_exe"
    set svdpi_include "$vivado_dir/data/xsim/include"
    
    # Find Python in Vivado TPS
    set possible_tps_dirs [list "$vivado_dir/tps/win64" "$vivado_dir/../tps/win64"]
    set python_glob ""
    foreach tps_dir $possible_tps_dirs {
        if {[file exists $tps_dir]} {
            set found_dirs [glob -nocomplain -directory "$tps_dir" "python-*"]
            foreach dir $found_dirs {
                if {[file exists "$dir/include/Python.h"]} {
                    set python_glob $dir
                    break
                }
            }
        }
        if {$python_glob ne ""} { break }
    }
    
    if {$python_glob eq ""} {
        puts "Error: Could not find Python in [join $possible_tps_dirs , ]"
        return
    }
    set python_dir [lindex $python_glob 0]
    set python_include "$python_dir/include"
    set python_libs "$python_dir/libs"
    
    puts "Using Python from: $python_dir"
    
    # Find python .lib file
    set python_lib_files [glob -nocomplain -directory $python_libs "python*.lib"]
    if {$python_lib_files eq ""} {
        puts "Error: Could not find .lib in $python_libs"
        return
    }
    
    set python_lib_path ""
    foreach lib $python_lib_files {
        set lib_name [file tail $lib]
        if {[regexp {python[0-9]{2,}\.lib} $lib_name]} {
            set python_lib_path $lib
            break
        }
    }
    if {$python_lib_path eq ""} {
        set python_lib_path [lindex $python_lib_files 0]
    }
    
    puts "Using Python Lib: $python_lib_path"
    
    # Normalize paths
    set python_include_native [file nativename $python_include]
    set svdpi_include_native [file nativename $svdpi_include]
    set python_lib_native [file nativename $python_lib_path]
    set wrapper_native [file nativename "wrapper.c"]
    
    set gcc_bin_dir [file dirname $gcc_exe]
    set ar_exe "$gcc_bin_dir/ar.exe"
    if {![file exists $ar_exe]} {
        puts "Error: AR not found at $ar_exe"
        return
    }
    
    # Create output directory
    set out_dir "xsim.dir/work/xsc"
    file mkdir $out_dir
    
    # Compile wrapper
    puts "Compiling wrapper.c -> wrapper.o"
    set wrapper_obj "$out_dir/wrapper.o"
    if {[catch {exec $gcc_exe -c -fPIC -o $wrapper_obj $wrapper_native \
        -I$svdpi_include_native \
        -I$python_include_native \
        >@stdout 2>@1} err]} {
        puts "Error Compiling: $err"
        return
    }
    
    # Link DLL
    puts "Linking wrapper.o -> libdpi.dll"
    set dpi_dll "$out_dir/libdpi.dll"
    set dpi_a   "$out_dir/libdpi.a"
    
    if {[catch {exec $gcc_exe -shared -o $dpi_dll $wrapper_obj \
        $python_lib_native \
        "-Wl,--out-implib,$dpi_a" \
        >@stdout 2>@1} err]} {
        puts "Error Linking DLL: $err"
        return
    }
    
    # Copy DLLs and model
    set python_dlls [glob -nocomplain -directory $python_dir "python3*.dll"]
    if {$python_dlls eq ""} {
        set python_dlls [glob -nocomplain -directory "$python_dir/bin" "python3*.dll"]
    }
    
    if {$python_dlls ne ""} {
        foreach dll $python_dlls {
            file copy -force $dll .
        }
        set mingw_dlls [glob -nocomplain -directory $gcc_bin_dir "lib*.dll"]
        foreach dll $mingw_dlls {
            file copy -force $dll .
        }
        file copy -force $dpi_dll .
        
        set model_file "../../model/{{ model_file }}"
        if {[file exists $model_file]} {
            file copy -force $model_file .
        } else {
            puts "WARNING: Python model not found at $model_file"
        }
    }
    
    puts "### \[1/3\] Compiling (xvlog) ###"
    if {[catch {exec xvlog -sv -L uvm \
        {{ vip_include_flags }} \
        {{ dut_files }} \
        {{ vip_files }} \
        {{ tb_files }} \
        >@stdout 2>@1} err]} {
        puts "Error: $err"
        return
    }
    
    puts "### \[2/3\] Elaborating (xelab) ###"
    if {[catch {exec xelab -L uvm -debug typical top -s top_snapshot -sv_lib libdpi -sv_root . \
        >@stdout 2>@1} err]} {
        puts "Error: $err"
        return
    }
    
    puts "### \[3/3\] Simulating (xsim) ###"
    catch {exec xsim top_snapshot -runall -log $log_file >@stdout 2>@1} sim_result
    
    # Save report after simulation
    save_report $log_file $report_dir $timestamp "{{ protocol }}"
}

#=============================================================================
# MAIN - Execute simulation
#=============================================================================
run_simulation
