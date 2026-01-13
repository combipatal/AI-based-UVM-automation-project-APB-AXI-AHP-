# Tcl script to run simulation in Vivado (Project-less flow)
# Run with: vivado -mode batch -source run.tcl

# === Setup Report Directory ===
# Use absolute path based on current working directory
set base_dir [file dirname [file dirname [pwd]]]
set report_dir [file join $base_dir "report"]
puts "Report directory: $report_dir"

if {![file exists $report_dir]} {
    file mkdir $report_dir
    puts "Created report directory: $report_dir"
}
set timestamp [clock format [clock seconds] -format "%Y-%m-%d_%H%M%S"]
set log_file "simulation_$timestamp.log"


puts "### [0/3] Compiling C Wrapper (gcc -> dll) ###"

# Clean up previous build artifacts to prevent stale linking (e.g. dpi.a)
file delete -force "xsim.dir"
file delete -force "dpi.dll" "apb_dpi.dll" "libdpi.dll"
# (Delete other logs if needed, but xsim.dir is the critical one for linker pollution)

# Find GCC in Vivado installation
set vivado_dir $env(XILINX_VIVADO)
set gcc_glob [glob -nocomplain -directory "$vivado_dir/tps/mingw" "*"]
if {$gcc_glob eq ""} {
    puts "Error: Could not find MinGW in $vivado_dir/tps/mingw"
    return
}
# Pick the first one (e.g. 6.2.0)
set mingw_dir [lindex $gcc_glob 0]
set gcc_exe "$mingw_dir/win64.o/nt/bin/gcc.exe"

if {![file exists $gcc_exe]} {
     puts "Error: GCC not found at $gcc_exe"
     return
}

puts "Using GCC: $gcc_exe"
set svdpi_include "$vivado_dir/data/xsim/include"

# Find Python in Vivado TPS
# Check internal tps first, then sibling tps
set possible_tps_dirs [list "$vivado_dir/tps/win64" "$vivado_dir/../tps/win64"]
set python_glob ""
foreach tps_dir $possible_tps_dirs {
    if {[file exists $tps_dir]} {
        set found_dirs [glob -nocomplain -directory "$tps_dir" "python-*"]
        foreach dir $found_dirs {
             # Check if header exists in this candidate
             if {[file exists "$dir/include/Python.h"]} {
                 set python_glob $dir
                 break
             } else {
                 puts "DEBUG: Found python dir $dir but NO Python.h inside."
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

# Find specific python .lib file (e.g. python38.lib or python3.lib)
set python_lib_files [glob -nocomplain -directory $python_libs "python*.lib"]
if {$python_lib_files eq ""} {
    puts "Error: Could not find .lib in $python_libs"
    return
}

# Logic: Prefer python3XX.lib over python3.lib
set python_lib_path ""
foreach lib $python_lib_files {
    set lib_name [file tail $lib]
    # Check if it has numbers >= 30, e.g. python313.lib
    # naive regex: python[0-9][0-9]+.lib
    if {[regexp {python[0-9]{2,}\.lib} $lib_name]} {
        set python_lib_path $lib
        break
    }
}

# Fallback: if no versioned lib found, use the first one (likely python3.lib)
if {$python_lib_path eq ""} {
    set python_lib_path [lindex $python_lib_files 0]
}

puts "Using Python Lib: $python_lib_path"

# Normalize paths to Windows native format (backslashes)
set python_include_native [file nativename $python_include]
set svdpi_include_native [file nativename $svdpi_include]
set python_lib_native [file nativename $python_lib_path]
set wrapper_native [file nativename "wrapper.c"]

# Note: Removed manual quotes around variables. Tcl exec handles spaces automatically.
# Adding quotes manually (e.g. "-I$var") usually passes literal quotes to the program on Windows.

# Determine AR executable (usually in same bin dir as GCC)
set gcc_bin_dir [file dirname $gcc_exe]
set ar_exe "$gcc_bin_dir/ar.exe"
if {![file exists $ar_exe]} {
     puts "Error: AR not found at $ar_exe"
     return
}
puts "Using AR: $ar_exe"

puts "DEBUG: Starting Manual Build (Mimicking xsc)..."

# 1. Create Output Directory Structure (xsim.dir/work/xsc)
# This is where xelab expects to find dpi.a and dpi.dll by default for library 'work'
set out_dir "xsim.dir/work/xsc"
file mkdir $out_dir

# 2. Compile Wrapper Object (wrapper.o)
puts "Step 1: Compiling wrapper.c -> wrapper.o"
set wrapper_obj "$out_dir/wrapper.o"
if {[catch {exec $gcc_exe -c -fPIC -o $wrapper_obj $wrapper_native \
    -I$svdpi_include_native \
    -I$python_include_native \
    >@stdout 2>@1} err]} {
    puts "Error Compiling: $err"
    return
}

# 3. Create Shared Library (libdpi.dll) AND Import Library (libdpi.a)
# We do NOT use 'ar' to make a static archive of the object file.
# Instead, we tell GCC to generate an import library for the DLL.
# This import library tells xelab "symbols X, Y, Z are in libdpi.dll".
# It prevents xelab from seeing the Python dependencies inside the object code.

puts "Step 2: Linking wrapper.o -> libdpi.dll (and generating libdpi.a)"
set dpi_dll "$out_dir/libdpi.dll"
set dpi_a   "$out_dir/libdpi.a"

# -Wl,--out-implib,filename tells the linker to create the import library
if {[catch {exec $gcc_exe -shared -o $dpi_dll $wrapper_obj \
    $python_lib_native \
    "-Wl,--out-implib,$dpi_a" \
    >@stdout 2>@1} err]} {
    puts "Error Linking DLL: $err"
    return
}
puts "Build Complete: Created $dpi_dll and import lib $dpi_a"

# Search for python3*.dll to ensure we add the correct dir to PATH
set python_dlls [glob -nocomplain -directory $python_dir "python3*.dll"]
if {$python_dlls eq ""} {
    # Try looking in bin/ just in case?
    set python_dlls [glob -nocomplain -directory "$python_dir/bin" "python3*.dll"]
}

if {$python_dlls eq ""} {
    puts "WARNING: Could not find python3*.dll in $python_dir. Simulation might fail to load DPI."
} else {
    # Method 3: FLATTEN Python DLLs to current directory.
    # We still need Python runtime DLLs alongside the xsim executable or in CWD.
    puts "DEBUG: Copying Python DLLs to current directory: [pwd]"
    
    foreach dll $python_dlls {
        file copy -force $dll .
    }
    
    # Copy MinGW Runtime DLLs to current directory too
    set mingw_dlls [glob -nocomplain -directory $gcc_bin_dir "lib*.dll"]
    foreach dll $mingw_dlls {
        file copy -force $dll .
    }

    # Also copy the generated dpi.dll to CWD just in case xelab checks there too
    file copy -force $dpi_dll .
    
    # 3. Copy Python Model File ({{ model_file }})
    # The wrapper expects '{{ model_module_name }}.py' to be importable.
    set model_file "../../model/{{ model_file }}"
    if {[file exists $model_file]} {
        puts "DEBUG: Copying Python Model: $model_file -> ."
        file copy -force $model_file .
    } else {
        puts "WARNING: Python model not found at $model_file"
    }
    
    # Debug: List what we have
    puts "DEBUG: Files in [pwd]:"
    foreach f [glob -nocomplain *.dll *.py] { puts "  - [file tail $f]" }
}

puts "### [1/3] Compiling (xvlog) ###"
# Note: Using 'exec' to run command-line tools. 
# redirect stdout to console
if {[catch {exec xvlog -sv -L uvm \
    {{ vip_include_flags }} \
    {{ dut_files }} \
    {{ vip_files }} \
    {{ tb_files }} \
    >@stdout 2>@1} err]} {
    puts "Error: $err"
    return
}

puts "### [2/3] Elaborating (xelab) ###"
# Link the compiled DPI library (xsc generates 'xsc_dpi' or similar by default, usually linked automatically or needs -sv_lib)
# xsc generates a shared library. In Vivado, 'xsc' output is automatically picked up if in the same dir?
# No, we refer to documentation. 'xsc' creates 'xsim.dir/work/xsc/dpi.so' (linux) or 'dpi.dll' (win)
# Usage: xelab ... -sv_lib dpi (looks for dpi.dll)
# We generated libdpi.dll manually.
if {[catch {exec xelab -L uvm -debug typical top -s top_snapshot -sv_lib libdpi -sv_root . \
    >@stdout 2>@1} err]} {
    puts "Error: $err"
    return
}

puts "### [3/3] Simulating (xsim) ###"
# Using exec to run simulation and capture all output
# -R runs simulation and generates log, then exits xsim
# We use exec to ensure script continues after xsim finishes
puts "Starting simulation..."

if {[catch {exec xsim top_snapshot -runall -log $log_file >@stdout 2>@1} sim_result]} {
    puts "Simulation completed (or error): $sim_result"
}

# === Save Log to Report Directory ===
puts "### Saving Simulation Log ###"
puts "Looking for log file: $log_file"
puts "Report directory: $report_dir"

if {[file exists $log_file]} {
    set dest_log [file join $report_dir $log_file]
    file copy -force $log_file $dest_log
    puts "Log saved to: $dest_log"
    
    # Also create a summary file
    set summary_file [file join $report_dir "summary_$timestamp.txt"]
    set fp [open $summary_file w]
    puts $fp "=== UVM {{ protocol | upper }} Simulation Summary ==="
    puts $fp "Timestamp: $timestamp"
    puts $fp "Log File: $log_file"
    puts $fp ""
    # Extract UVM report summary from log
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
    puts "Summary saved to: $summary_file"
} else {
    puts "WARNING: Log file not found: $log_file"
    puts "Files in current directory:"
    foreach f [glob -nocomplain *.log] { puts "  - $f" }
}

puts "### Simulation Complete ###"


