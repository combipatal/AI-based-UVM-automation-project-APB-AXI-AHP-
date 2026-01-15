"""
AI Test Plan Generator
자연어 프로토콜 설명 → test_plan YAML 자동 생성

사용법 (파일 입력 전용):
    python -m main.ai_planner --input spec.txt --output config.yaml
"""


import yaml
import argparse
import subprocess
from pathlib import Path

OLLAMA_MODEL = "qwen2.5-coder:7b"
VIP_SIGNALS_PATH = Path(__file__).parent.parent / "templates" / "vip" / "vip_signals.yaml"


def load_vip_signals() -> dict:
    """Load VIP signal definitions from vip_signals.yaml"""
    if not VIP_SIGNALS_PATH.exists():
        return {}
    with open(VIP_SIGNALS_PATH, 'r') as f:
        return yaml.safe_load(f) or {}


def get_vip_signals_prompt_section() -> str:
    """Generate VIP signals section for AI prompt"""
    vip_signals = load_vip_signals()
    if not vip_signals:
        return ""
    
    sections = []
    for protocol, info in vip_signals.items():
        signals_str = ", ".join(info.get('signals', []))
        sections.append(f"    - **{protocol.upper()}**: {signals_str}")
    
    return "\n".join(sections)

SYSTEM_PROMPT_TEMPLATE = """You are a UVM verification expert. 
Your goal is to generate a COMPLETE `config.yaml` file for a UVM testbench generator based on the user's provided specification (which may include Verilog code).

### Instructions:
1. **Analyze Verilog Parameters**: Look for parameters like `ADDR_WIDTH`, `DATA_WIDTH`, and `RAM_DEPTH`.
   - Calculate the memory size in bytes. (e.g., RAM_DEPTH=256, DATA_WIDTH=32(4bytes) -> Size = 1024 bytes).
   - Set `constraints.addr.max` based on this calculated size (e.g., 1024 - 4 = 1020).
2. **Identify Interfaces**: Detect protocols (APB, AXI, AHB) and map ports by SEMANTIC MEANING.
3. **Generate Full Config**: Output a valid YAML with `project_name`, `dut`, `interfaces`, and `test_plan`.
   - **CRITICAL PORT_MAP RULES**:
     - **KEY** = EXACT Verilog port name from the DUT code
     - **VALUE** = FIXED standard interface signal name (from the list below)
     - **Match by SEMANTIC MEANING, not just name similarity**
     - **NEVER copy the DUT port name as the value if it differs from the standard!**
   - **Protocol Standard Signals (FIXED - use these EXACT names as VALUES)**:
{vip_signals_section}
   - **Semantic Mapping Examples**:
     - DUT `input clk` → VALUE `pclk` (both are clocks for APB)
     - DUT `input HCLK` → VALUE `hclk` (both are clocks for AHB)
     - DUT `input rst_n` → VALUE `presetn` (both are active-low resets)
     - DUT `output rdata` → VALUE `prdata` (both are read data in APB)
     - DUT `input HSELx` → VALUE `hsel` (both are slave select)
   - **Confidence**: Only map if 80%+ confident the signals serve the same purpose

### Output Format (YAML ONLY):

```yaml
project_name: <string>
output_dir: "./output"

dut:
  module_name: <string>
  source_files: 
    - <path_to_verilog>
  parameters:
    ADDR_WIDTH: <val>
    DATA_WIDTH: <val>
    # Add others found in spec

interfaces:
  - name: "vif_0"
    protocol: <apb|axi|ahb>
    type: <master|slave>
    port_map:
      <dut_port>: <interface_signal>

test_plan:
  constraints:
    addr:
      min: 0
      max: <calculated_max_addr>
      align: <data_width_bytes>
    data:
      type: random
    iterations: <int>
  coverage:
    addr_ranges:
      - name: low
        range: [<start>, <end>]
      # Split memory range into meaningful bins
    corner_cases:
      - "boundary_addr: 0x0, <max_addr_hex>"
      # Add other relevant cases
```
"""

EXAMPLE_INPUT = """
Spec:
- APB slave memory
- File: rtl/mem.v
Code:
parameter RAM_DEPTH = 256; // 32-bit width
input pclk, presetn, ...
"""

EXAMPLE_OUTPUT = """project_name: apb_mem_project
output_dir: "./output"

dut:
  module_name: apb_slave_mem
  source_files:
    - "rtl/mem.v"
  parameters:
    ADDR_WIDTH: 32
    DATA_WIDTH: 32
    RAM_DEPTH: 256

interfaces:
  - name: "vif_0"
    protocol: "apb"
    type: "slave"
    port_map:
      pclk: "pclk"
      presetn: "presetn"
      paddr: "paddr"
      psel: "psel"
      penable: "penable"
      pwrite: "pwrite"
      pwdata: "pwdata"
      pready: "pready"
      prdata: "prdata"
      pslverr: "pslverr"

test_plan:
  constraints:
    addr:
      min: 0
      max: 1020  # 256 * 4 - 4
      align: 4
    data:
      type: random
    iterations: 100
  coverage:
    addr_ranges:
      - name: "low"
        range: [0, 255]
      - name: "high"
        range: [768, 1023]
    corner_cases:
      - "boundary_addr: 0x0, 0x3FC"
"""

AHB_EXAMPLE_INPUT = """
Spec:
- AHB-Lite slave memory
- File: UVM/AHB/ahb_slave_mem.v
Code:
module ahb_slave_mem (
    input           HCLK,
    input           HRESETn,
    input   [31:0]  HADDR,
    input   [1:0]   HTRANS,
    input           HWRITE,
    input   [2:0]   HSIZE,
    input   [31:0]  HWDATA,
    output  [31:0]  HRDATA,
    output          HREADY,
    output          HRESP,
    input           HSELx
);
reg [31:0] memory [0:1023];  // 4KB memory
"""

AHB_EXAMPLE_OUTPUT = """project_name: ahb_mem_project
output_dir: "./output"

dut:
  module_name: ahb_slave_mem
  source_files:
    - "UVM/AHB/ahb_slave_mem.v"
  parameters:
    ADDR_WIDTH: 32
    DATA_WIDTH: 32

interfaces:
  - name: "vif_0"
    protocol: "ahb"
    type: "slave"
    port_map:
      HCLK: "hclk"
      HRESETn: "hresetn"
      HADDR: "haddr"
      HTRANS: "htrans"
      HWRITE: "hwrite"
      HSIZE: "hsize"
      HWDATA: "hwdata"
      HRDATA: "hrdata"
      HREADY: "hready"
      HRESP: "hresp"
      HSELx: "hsel"

test_plan:
  constraints:
    addr:
      min: 0
      max: 4092  # 4KB - 4 = 4096 - 4
      align: 4
    data:
      type: random
    iterations: 100
  coverage:
    addr_ranges:
      - name: "low"
        range: [0, 1023]
      - name: "mid"
        range: [1024, 3071]
      - name: "high"
        range: [3072, 4095]
    corner_cases:
      - "boundary_addr: 0x0, 0xFFC"
      - "size_variation: BYTE, HALFWORD, WORD"
"""


def call_ollama(prompt: str) -> str:
    """로컬 Ollama API 호출"""
    try:
        # ollama run 명령 사용 (더 간단)
        result = subprocess.run(
            ["ollama", "run", OLLAMA_MODEL, prompt],
            capture_output=True,
            text=True,
            encoding='utf-8',  # Windows 인코딩 문제 해결
            timeout=120
        )
        return result.stdout.strip()
    except FileNotFoundError:
        print("Error: Ollama not installed. Install from https://ollama.ai")
        return None
    except subprocess.TimeoutExpired:
        print("Error: Ollama timeout")
        return None


def build_prompt(user_input: str) -> str:
    vip_signals_section = get_vip_signals_prompt_section()
    system_prompt = SYSTEM_PROMPT_TEMPLATE.format(vip_signals_section=vip_signals_section)
    
    return f"""{system_prompt}

### User Input:
{user_input}

### Output (YAML only):
"""


def parse_yaml_response(response: str) -> dict:
    """LLM 응답에서 YAML 추출 및 파싱"""
    # ```yaml ... ``` 블록 추출
    if "```yaml" in response:
        start = response.find("```yaml") + 7
        end = response.find("```", start)
        if end == -1: end = len(response)
        yaml_str = response[start:end].strip()
    elif "```" in response:
        start = response.find("```") + 3
        end = response.find("```", start)
        if end == -1: end = len(response)
        yaml_str = response[start:end].strip()
    else:
        yaml_str = response.strip()
    
    try:
        return yaml.safe_load(yaml_str)
    except yaml.YAMLError as e:
        print(f"YAML Parse Error: {e}")
        return None


def validate_config(config: dict) -> bool:
    """config.yaml 스키마 검증"""
    if not config:
        return False
    
    required_keys = ["project_name", "dut", "interfaces", "test_plan"]
    for key in required_keys:
        if key not in config:
            print(f"Error: Required key '{key}' missing")
            return False
    return True


def post_process_config(config: dict) -> dict:
    if 'dut' in config and 'dut_parameters' not in config['dut']:
        config['dut']['dut_parameters'] = {}
    return config


def generate_test_plan(user_input: str) -> dict:
    print(f"\n[AI] Generating full configuration using {OLLAMA_MODEL}...")
    
    prompt = build_prompt(user_input)
    response = call_ollama(prompt)
    
    if not response:
        return None
    
    print(f"\n[AI] Raw response length: {len(response)} chars")
    
    config = parse_yaml_response(response)
    
    if validate_config(config):
        config = post_process_config(config)
        print("[AI] Valid configuration generated!")
        return config
    else:
        print("[AI] Invalid configuration structure")
        return None


def save_config(config: dict, config_path: str = "config.yaml"):
    """전체 config 저장"""
    config_file = Path(config_path)
    
    with open(config_file, 'w', encoding='utf-8') as f:
        yaml.dump(config, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    
    print(f"[AI] Saved to: {config_path}")


def main():
    parser = argparse.ArgumentParser(description="AI Config Generator (파일 입력 전용)")
    parser.add_argument("--input", "-f", type=str, required=True,
                        help="입력 파일 경로 (spec.txt)")
    parser.add_argument("--output", "-o", type=str, default="config.yaml",
                        help="출력 파일 경로")
    
    args = parser.parse_args()

    with open(args.input, 'r', encoding='utf-8') as f:
        user_input = f.read()
    
    config = generate_test_plan(user_input)
    if config:
        save_config(config, args.output)
    else:
        print("[AI] Config 생성 실패: 응답을 확인하세요.")
        exit(1)


if __name__ == "__main__":
    main()

