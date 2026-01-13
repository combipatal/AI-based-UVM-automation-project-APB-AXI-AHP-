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

# Ollama API 설정 (CLI 사용)
OLLAMA_MODEL = "deepseek-coder-v2:latest"

# 프롬프트 템플릿

SYSTEM_PROMPT = """You are a UVM verification expert. 
Your goal is to generate a COMPLETE `config.yaml` file for a UVM testbench generator based on the user's provided specification (which may include Verilog code).

### Instructions:
1. **Analyze Verilog Parameters**: Look for parameters like `ADDR_WIDTH`, `DATA_WIDTH`, and `RAM_DEPTH`.
   - Calculate the memory size in bytes. (e.g., RAM_DEPTH=256, DATA_WIDTH=32(4bytes) -> Size = 1024 bytes).
   - Set `constraints.addr.max` based on this calculated size (e.g., 1024 - 4 = 1020).
2. **Identify Interfaces**: Detect protocols (APB, AXI, etc.) and map ports.
   - Standard APB signals: pclk, presetn, paddr, psel, penable, pwrite, pwdata, pready, prdata, pslverr.
3. **Generate Full Config**: Output a valid YAML with `project_name`, `dut`, `interfaces`, and `test_plan`.
   - **CRITICAL PORT_MAP RULES**:
     - **KEY** = EXACT Verilog port name from the DUT code
     - **VALUE** = FIXED standard interface signal name (from the list below)
     - **NEVER copy the DUT port name as the value if it differs from the standard!**
   - **Protocol Standard Signals (FIXED - use these as VALUES)**:
     - **APB**: pclk, presetn, paddr, psel, penable, pwrite, pwdata, pready, prdata, pslverr
     - **AXI**: aclk, aresetn, awaddr, awvalid, awready, wdata, wstrb, wvalid, wready, bresp, bvalid, bready, araddr, arvalid, arready, rdata, rresp, rvalid, rready
   - **Examples**:
     - DUT: `input pclk` (standard name) -> `pclk: "pclk"` ✓
     - DUT: `input clk` (non-standard) -> `clk: "pclk"` ✓ (NOT `clk: "clk"` ✗)
     - DUT: `output rdata` (APB, non-standard) -> `rdata: "prdata"` ✓ (NOT `rdata: "rdata"` ✗)
     - DUT: `input s_axi_awaddr` (AXI) -> `s_axi_awaddr: "awaddr"` ✓

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
    """Few-shot 프롬프트 생성"""
    prompt = f"""{SYSTEM_PROMPT}

### User Input:
{user_input}

### Output (YAML only):
"""
    return prompt


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


def generate_test_plan(user_input: str) -> dict:
    """메인 함수: 자연어 → 전체 Config YAML 변환"""
    print(f"\n[AI] Generating full configuration using {OLLAMA_MODEL}...")
    
    prompt = build_prompt(user_input)
    response = call_ollama(prompt)
    
    if not response:
        return None
    
    print(f"\n[AI] Raw response length: {len(response)} chars")
    
    config = parse_yaml_response(response)
    
    if validate_config(config):
        print("[AI] Valid configuration generated!")
        return config
    else:
        print("[AI] Invalid configuration structure")
        # 디버깅을 위해 응답 출력
        # print(response) 
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

