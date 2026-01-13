import argparse
import os
import sys

def init_config(protocol):
    """Generates a starter config.yaml for the specified protocol."""
    content = f"""project_name: "my_uvm_project"
output_dir: "./output"

dut:
  module_name: "my_dut"
  source_files: 
    - "rtl/my_dut.v"
  parameters:
    ADDR_WIDTH: 32
    DATA_WIDTH: 32

interfaces:
  - name: "vif_0"
    protocol: "{protocol}"  # apb, axi, etc.
    type: "slave"        # master or slave
    
    # Port Mapping (DUT Port : VIP Interface Signal)
    port_map:
      # Example for {protocol}
      # pclk: "pclk"
"""
    if protocol == "apb":
        content += """      pclk:    "pclk"
      presetn: "presetn"
      paddr:   "paddr"
      psel:    "psel"
      penable: "penable"
      pwrite:  "pwrite"
      pwdata:  "pwdata"
      pready:  "pready"
      prdata:  "prdata"
      pslverr: "pslverr"
"""
    
    with open("config.yaml", "w") as f:
        f.write(content)
    print(f"[Success] Generated 'config.yaml' for protocol '{protocol}'")

def main():
    parser = argparse.ArgumentParser(description="UVM Testbench Generator")
    parser.add_argument("--init", type=str, help="Generate a starter config.yaml for the given protocol (e.g., apb)")
    parser.add_argument("--config", type=str, help="Path to config.yaml to run generation", default="config.yaml")
    
    args = parser.parse_args()

    if args.init:
        init_config(args.init)
        return

    if not os.path.exists(args.config):
        print(f"[Error] Config file '{args.config}' not found.")
        print("Run 'python main/run.py --init apb' to generate one.")
        sys.exit(1)

    print(f"[Info] Loading configuration from '{args.config}'...")
    
    # Import modules dynamically to avoid import errors if dependencies are missing during init
    from main.utils.config_loader import load_config
    from main.utils.generator import Generator

    config = load_config(args.config)
    
    gen = Generator(config)
    gen.generate()
    print("[Success] Generation completed.")

if __name__ == "__main__":
    main()
