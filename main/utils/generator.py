import os
import sys
from .verilog_parser import parse_all_dut_sources

try:
    from jinja2 import Environment, FileSystemLoader
except ImportError:
    print("[Error] Jinja2 is not installed. Please install it using 'pip install jinja2'")
    sys.exit(1)

class Generator:
    def __init__(self, config):
        self.config = config
        self.output_dir = config['output_dir']
        self.template_env = Environment(loader=FileSystemLoader('.'))

    def generate(self):
        """
        Main generation flow.
        """
        self.prepare_output_dir()
        self.copy_vip_files()
        self.generate_tb_top()
        self.generate_tb_env()
        self.generate_test()
        self.generate_tb_pkg()
        self.generate_tcl_script()
        self.generate_dpi_wrapper()
        # Add more generation steps here (Wrappers, Tests, etc.)

    def prepare_output_dir(self):
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)
        
        # Create subdirectories
        os.makedirs(os.path.join(self.output_dir, "tb"), exist_ok=True)
        os.makedirs(os.path.join(self.output_dir, "sim"), exist_ok=True)

    def generate_tb_top(self):
        """
        Render templates/tb/top.sv -> {output_dir}/tb/top.sv
        """
        template_path = "templates/tb/top.sv"
        if not os.path.exists(template_path):
             print(f"[Warning] Template not found: {template_path}. Skipping Top generation.")
             return

        template = self.template_env.get_template(template_path)
        
        PROTOCOL_CLOCKS = {'apb': 'pclk', 'axi': 'aclk', 'ahb': 'hclk'}
        PROTOCOL_RESETS = {'apb': 'presetn', 'axi': 'aresetn', 'ahb': 'hresetn'}
        
        vip_params = self.config['dut'].get('parameters', {}) or {}
        dut_inst_params = self.config['dut'].get('dut_parameters', {}) or {}
        
        context = {
            'vip_packages': [f"{intf['protocol']}_pkg" for intf in self.config['interfaces']],
            'interfaces': [
                {
                    'type': f"{intf['protocol']}_if",
                    'name': intf['name'],
                    'protocol': intf['protocol'],
                    'clock': PROTOCOL_CLOCKS.get(intf['protocol'], 'pclk'),
                    'reset': PROTOCOL_RESETS.get(intf['protocol'], 'presetn')
                } for intf in self.config['interfaces']
            ],
            'dut_name': self.config['dut']['module_name'],
            'dut_parameters': dut_inst_params,
            'addr_width': vip_params.get('ADDR_WIDTH', 32),
            'data_width': vip_params.get('DATA_WIDTH', 32),
            'default_test': f"{self.config['interfaces'][0]['protocol']}_test",
            'port_maps': self._build_port_maps(self.config['interfaces'])
        }

        rendered = template.render(context)
        
        out_path = os.path.join(self.output_dir, "tb", "top.sv")
        with open(out_path, "w") as f:
            f.write(rendered)
        print(f"[Generated] {out_path}")

    def generate_tcl_script(self):
        """
        Render templates/sim/run.tcl -> {output_dir}/sim/run.tcl
        """
        template_path = "templates/sim/run.tcl"
        if not os.path.exists(template_path):
             print(f"[Warning] Template not found: {template_path}. Skipping Tcl generation.")
             return

        template = self.template_env.get_template(template_path)
        
        vip_files = []
        for intf in self.config['interfaces']:
            proto = intf['protocol']
            vip_files.append(f"../vip/{proto}/{proto}_pkg.sv")
            vip_files.append(f"../vip/{proto}/{proto}_if.sv")

        dut_files_rel = []
        for f in self.config['dut']['source_files']:
            rel = os.path.join("..", "..", f).replace("\\", "/")
            dut_files_rel.append(rel)

        # Get Python Paths
        import sysconfig
        import sys
        py_include = sysconfig.get_path('include').replace("\\", "/")
        
        # Library Path (Windows: <base>/libs)
        py_base = sys.base_prefix.replace("\\", "/")
        py_lib_dir = os.path.join(py_base, "libs").replace("\\", "/")
        
        # Library Name (python3x.lib)
        ver_major = sys.version_info.major
        ver_minor = sys.version_info.minor
        py_lib_name = f"python{ver_major}{ver_minor}" # e.g. python313

        # Determine Primary Protocol and Model
        if self.config['interfaces']:
            primary_proto = self.config['interfaces'][0]['protocol']
            model_module_name = f"{primary_proto}_model"
            model_file_name = f"{primary_proto}_model.py"
        else:
            primary_proto = "apb"
            model_module_name = "apb_model"
            model_file_name = "apb_model.py"

        # Build VIP Include Flags
        # Get unique protocols
        protocols = set(intf['protocol'] for intf in self.config['interfaces'])
        vip_include_flags = []
        for p in protocols:
            vip_include_flags.append(f"-i ../vip/{p}")
        vip_includes_str = " ".join(vip_include_flags)

        context = {
            'dut_files': " ".join(dut_files_rel),
            'vip_files': " ".join(vip_files),
            'tb_files': "../tb/tb_pkg.sv ../tb/top.sv", # Compile pkg then top
            'python_include': py_include,
            'python_lib_dir': py_lib_dir,
            'python_lib_name': py_lib_name,
            'protocol': primary_proto,
            'model_file': model_file_name,
            'vip_includes': vip_include_flags, # Passing list creates issues if not joined or handled in template. Let's pass string or handle list.
            # Actually run.tcl template expects string substitution currently if we use {{ vip_includes }}
            # Let's check template. Template uses: -i ../vip/apb. 
            # We will replace that line in template.
            'vip_include_flags': vip_includes_str,
            'model_module_name': model_module_name
        }

        rendered = template.render(context)
        
        out_path = os.path.join(self.output_dir, "sim", "run.tcl")
        with open(out_path, "w") as f:
            f.write(rendered)
        print(f"[Generated] {out_path}")

    def generate_tb_env(self):
        """
        Render templates/tb/tb_env.sv -> {output_dir}/tb/tb_env.sv
        """
        template_path = "templates/tb/tb_env.sv"
        if not os.path.exists(template_path): return

        template = self.template_env.get_template(template_path)
        
        # Build context for agents
        interfaces_ctx = []
        for intf in self.config['interfaces']:
            interfaces_ctx.append({
                'name': intf['name'],
                'agent_type': f"{intf['protocol']}_agent",
                'protocol': intf['protocol']
            })

        context = { 'interfaces': interfaces_ctx }
        rendered = template.render(context)
        
        out_path = os.path.join(self.output_dir, "tb", "tb_env.sv")
        with open(out_path, "w") as f:
            f.write(rendered)
        print(f"[Generated] {out_path}")

    def generate_tb_pkg(self):
        """
        Render templates/tb/tb_pkg.sv -> {output_dir}/tb/tb_pkg.sv
        """
        template_path = "templates/tb/tb_pkg.sv"
        if not os.path.exists(template_path): return

        template = self.template_env.get_template(template_path)
        
        vip_pkgs = [f"{intf['protocol']}_pkg" for intf in self.config['interfaces']]
        test_name = f"{self.config['interfaces'][0]['protocol']}_test"
        context = { 
            'vip_packages': vip_pkgs,
            'test_name': test_name
        }
        
        rendered = template.render(context)
        
        out_path = os.path.join(self.output_dir, "tb", "tb_pkg.sv")
        with open(out_path, "w") as f:
            f.write(rendered)
        print(f"[Generated] {out_path}")

    def generate_test(self):
        """
        Render templates/test/apb_test.sv -> {output_dir}/tb/apb_test.sv
        Note: We put tests in tb/ directory to be included by tb_pkg easily, 
        or we should have a tests/ dir. For now, output/tb/apb_test.sv is fine.
        """
        # Determine Primary Protocol
        if self.config['interfaces']:
            primary_proto = self.config['interfaces'][0]['protocol']
        else:
            primary_proto = "apb" # Fallback

        template_path = f"templates/test/{primary_proto}_test.sv"
        if not os.path.exists(template_path):
            print(f"[WARNING] Test template not found: {template_path}")
            return
        
        template = self.template_env.get_template(template_path)
        
        # Determine bit widths from Config
        # Assuming single interface for now or uniform width
        addr_width = self.config['dut']['parameters'].get('ADDR_WIDTH', 32)
        data_width = self.config['dut']['parameters'].get('DATA_WIDTH', 32)
        
        interfaces_ctx = []
        for intf in self.config['interfaces']:
            interfaces_ctx.append({ 'name': intf['name'] })

        context = {
            'addr_width': addr_width,
            'data_width': data_width,
            'interfaces': interfaces_ctx
        }
        
        rendered = template.render(context)
        
        out_path = os.path.join(self.output_dir, "tb", f"{primary_proto}_test.sv")
        with open(out_path, "w") as f:
            f.write(rendered)
        print(f"[Generated] {out_path}")

    def generate_dpi_wrapper(self):
        """
        Copy templates/dpi/wrapper.c -> {output_dir}/sim/wrapper.c
        """
        template_path = "templates/dpi/wrapper.c"
        if not os.path.exists(template_path):
             print(f"[Warning] Template not found: {template_path}. Skipping DPI wrapper generation.")
             return

        # No Jinja2 rendering needed for now, just copy, or maybe render if flexible
        # Determine model name from protocol of the first interface
        # e.g. apb -> apb_model
        if self.config['interfaces']:
            proto = self.config['interfaces'][0]['protocol']
            model_name = f"{proto}_model"
        else:
            model_name = "apb_model" # Fallback

        context = {
            'model_module_name': model_name
        }
        
        template = self.template_env.get_template(template_path)
        rendered = template.render(context)
        
        out_path = os.path.join(self.output_dir, "sim", "wrapper.c")
        with open(out_path, "w") as f:
            f.write(rendered)
        print(f"[Generated] {out_path}")

    def copy_vip_files(self):
        protocols = set(intf['protocol'] for intf in self.config['interfaces'])
        
        # Auto-infer bit widths from DUT source files
        inferred_widths = parse_all_dut_sources(
            self.config['dut'].get('source_files', [])
        )
        
        # Protocol-specific clock/reset names
        PROTOCOL_CLOCKS = {'apb': 'pclk', 'axi': 'aclk', 'ahb': 'hclk'}
        PROTOCOL_RESETS = {'apb': 'presetn', 'axi': 'aresetn', 'ahb': 'hresetn'}
        
        # Build context: config.yaml parameters override inferred values
        config_params = self.config['dut'].get('parameters', {}) or {}
        context = {
            'ADDR_WIDTH': config_params.get('ADDR_WIDTH', inferred_widths.get('ADDR_WIDTH', 32)),
            'DATA_WIDTH': config_params.get('DATA_WIDTH', inferred_widths.get('DATA_WIDTH', 32)),
            **config_params,
        }
        
        if 'test_plan' in self.config:
            context['test_plan'] = self.config['test_plan']

        for proto in protocols:
            # Add protocol-specific clock/reset to context
            context['clock_name'] = PROTOCOL_CLOCKS.get(proto, 'clk')
            context['reset_name'] = PROTOCOL_RESETS.get(proto, 'resetn')
            
            src_dir = os.path.join("templates", "vip", proto)
            dst_dir = os.path.join(self.output_dir, "vip", proto)
            
            if not os.path.exists(src_dir):
                print(f"[Warning] VIP template directory not found: {src_dir}")
                continue
                
            os.makedirs(dst_dir, exist_ok=True)

            # Iterate over all files in the VIP template directory
            for root, dirs, files in os.walk(src_dir):
                 for file in files:
                    src_path = os.path.join(root, file)
                    # Compute relative path to maintain structure inside vip/{proto}
                    rel_path = os.path.relpath(src_path, src_dir)
                    dst_path = os.path.join(dst_dir, rel_path)
                    
                    # Ensure subdirectories exist
                    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
                    
                    # Render the file
                    self._render_file(src_path, dst_path, context)
    
    def _render_file(self, src_path, dst_path, context):
        try:
            # We need to load template relative to where Environment was initialized (Current Dir)
            # src_path is like "templates/vip/apb/apb_driver.sv"
            # Since FileSystemLoader is '.', we can just use src_path (forward slashes preferred)
            src_path_normalized = src_path.replace("\\", "/") # Ensure jinja2 friendly path
            
            template = self.template_env.get_template(src_path_normalized)
            rendered = template.render(context)
            
            with open(dst_path, "w") as f:
                f.write(rendered)
            print(f"[Generated] {dst_path}")
        except Exception as e:
            print(f"[Error] Failed to render {src_path}: {e}")

    def _build_port_maps(self, interfaces):
        """
        Flatten port maps for Top module.
        Assuming DUT ports are unique or we are connecting single DUT.
        For multiple interfaces, we might need more complex logic.
        """
        maps = []
        for intf in interfaces:
            # { dut_port: intf_signal }
            for dut_p, intf_s in intf['port_map'].items():
                maps.append({
                    'dut_port': dut_p,
                    'intf_sig': f"{intf['name']}.{intf_s}"
                })
        return maps
