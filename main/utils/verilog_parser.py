"""
Verilog Port Width Parser

Parses Verilog source files to extract port bit widths.
Used to infer ADDR_WIDTH and DATA_WIDTH when not specified in config.yaml.
"""

import re
import os


def parse_port_widths(verilog_file_path):
    """
    Parse a Verilog file and extract port bit widths.
    
    Args:
        verilog_file_path: Path to the Verilog source file
        
    Returns:
        dict: Inferred parameters, e.g. {'ADDR_WIDTH': 32, 'DATA_WIDTH': 32}
    """
    if not os.path.exists(verilog_file_path):
        print(f"[Warning] Verilog file not found: {verilog_file_path}")
        return {}
    
    with open(verilog_file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    inferred = {}
    
    # Pattern to match port declarations with bit widths
    # Examples:
    #   input  wire [31:0] paddr,
    #   input wire[ADDR_WIDTH-1:0] paddr,
    #   output reg  [31:0] prdata,
    port_pattern = re.compile(
        r'(input|output)\s+(?:wire|reg)?\s*\[(\d+):0\]\s*(\w+)',
        re.IGNORECASE
    )
    
    for match in port_pattern.finditer(content):
        direction = match.group(1)
        msb = int(match.group(2))
        port_name = match.group(3).lower()
        width = msb + 1
        
        # Infer ADDR_WIDTH from address-related ports
        if any(keyword in port_name for keyword in ['addr', 'paddr', 'haddr', 'awaddr', 'araddr']):
            if 'ADDR_WIDTH' not in inferred:
                inferred['ADDR_WIDTH'] = width
                print(f"[Parser] Inferred ADDR_WIDTH={width} from port '{port_name}'")
        
        # Infer DATA_WIDTH from data-related ports
        if any(keyword in port_name for keyword in ['data', 'wdata', 'rdata', 'pwdata', 'prdata', 'hwdata', 'hrdata']):
            if 'DATA_WIDTH' not in inferred:
                inferred['DATA_WIDTH'] = width
                print(f"[Parser] Inferred DATA_WIDTH={width} from port '{port_name}'")
    
    return inferred


def parse_all_dut_sources(source_files, base_dir='.'):
    """
    Parse multiple DUT source files and merge inferred widths.
    
    Args:
        source_files: List of relative paths to Verilog files
        base_dir: Base directory for resolving relative paths
        
    Returns:
        dict: Merged inferred parameters
    """
    merged = {}
    
    for src_file in source_files:
        full_path = os.path.join(base_dir, src_file)
        widths = parse_port_widths(full_path)
        # First found value wins (don't overwrite)
        for key, value in widths.items():
            if key not in merged:
                merged[key] = value
    
    return merged
