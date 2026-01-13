import yaml
import os
import sys

def load_config(config_path):
    """
    Load and validate the configuration file.
    """
    if not os.path.exists(config_path):
        print(f"[Error] Config file not found: {config_path}")
        sys.exit(1)

    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        print(f"[Error] Failed to parse YAML: {e}")
        sys.exit(1)

    validate_config(config)
    return config

def validate_config(config):
    """
    Validate the configuration structure and values.
    """
    required_fields = ['project_name', 'output_dir', 'dut', 'interfaces']
    for field in required_fields:
        if field not in config:
            print(f"[Error] Missing required field in config: '{field}'")
            sys.exit(1)

    # Validate DUT
    dut = config['dut']
    if 'source_files' not in dut:
        print("[Error] DUT must specify 'source_files'.")
        sys.exit(1)
    
    for src in dut['source_files']:
        if not os.path.exists(src):
            print(f"[Error] DUT source file not found: {src}")
            sys.exit(1)

    # Validate Interfaces
    for intf in config['interfaces']:
        if 'name' not in intf or 'protocol' not in intf:
            print("[Error] Interface must have 'name' and 'protocol'.")
            sys.exit(1)
        
        # Check if VIP template exists
        # Assuming run.py is executed from project root, templates are in templates/vip/{protocol}
        template_dir = os.path.join("templates", "vip", intf['protocol'])
        if not os.path.exists(template_dir):
            print(f"[Error] Unsupported protocol '{intf['protocol']}'. Template directory not found: {template_dir}")
            sys.exit(1)

    print("[Info] Configuration validated successfully.")
