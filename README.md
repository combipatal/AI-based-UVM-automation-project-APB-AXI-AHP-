# UVM Testbench Generator - 환경 설정 및 주의사항

## 1. 프로젝트 개요 (Project Overview)

**AI 기반 UVM 자동화 솔루션**
이 프로젝트는 **Jinja2 템플릿 엔진**과 **Large Language Model (LLM)**을 결합하여 UVM 테스트벤치를 자동으로 생성하는 로컬 Python 툴입니다. 반복적인 코딩 작업을 줄이고, 검증 로직 구현에 집중할 수 있도록 돕습니다.

### 핵심 철학 (Core Philosophy)
- **Standard Protocol (APB, AXI, AHB 등)**: **검증된 VIP 템플릿**을 재사용하고, 신호 이름을 표준화(`vip_signals.yaml`)하여 신뢰성을 확보합니다.
- **AI-Based Semantic Mapping**: 사용자의 자연어 명세나 RTL 포트 이름을 AI가 분석하여 표준 VIP 신호와 의미론적으로(Semantically) 매핑합니다.
- **Verification = Golden Model**: Python으로 작성된 알고리즘을 **DPI-C**로 연결하여 Scoreboard에서 정밀하게 검증합니다.

### 주요 시스템 구조
1.  **입력**: RTL 명세(`spec.txt`), 프로토콜 선택, Python Golden Model.
2.  **AI Planner**: 
    *   `spec.txt` 분석 및 `vip_signals.yaml` 참조.
    *   DUT 포트와 VIP 신호 간의 의미론적 매핑 수행 -> `config.yaml` 생성.
3.  **생성기 (Generator)**:
    *   `config.yaml`을 기반으로 **표준화된 VIP 템플릿**에 포트 매핑 적용.
    *   Jinja2를 사용하여 DPI-C Wrapper, SV Import 등 정형화된 코드 자동 생성.
4.  **출력**: 실행 가능한 UVM 환경 (`tb`, `env`, `agents`, `sim` scripts).

## 필수 요구사항

### 1. Vivado 설치
- **버전**: Vivado 2023.x 이상 권장 (2025.1에서 테스트됨)
- **환경변수**: `XILINX_VIVADO`가 설정되어 있어야 함
  ```
  # Windows 예시
  XILINX_VIVADO=C:\Xilinx\2025.1\Vivado
  ```

### 2. Python (Generator용)
- **버전**: Python 3.8 이상
- **라이브러리**: `pyyaml`, `jinja2`
  ```bash
  pip install pyyaml jinja2
  ```

---

## 🚀 최신 업데이트 (2026.01.15) - VIP 표준화 및 AI 매핑 고도화

### 1. VIP 신호 표준화 (Single Source of Truth)
- `templates/vip/vip_signals.yaml` 파일을 도입하여 모든 프로토콜(AHB, APB, AXI)의 표준 신호 이름을 정의했습니다.
- Generator 하드코딩 로직을 제거하고, YAML 기반으로 유연하게 동작하도록 리팩토링했습니다.

### 2. AI Planner 매핑 능력 강화
- AI가 `vip_signals.yaml`의 정의를 참조하여 DUT의 포트 이름(예: `HCLK`)을 표준 VIP 신호(`hclk`)와 정확하게 매핑합니다.
- 복잡한 `if-else` 로직 없이 AI의 의미론적 이해를 통해 매핑이 이루어집니다.

### 3. 시뮬레이션 환경 개선
- **Vivado Echo 버그 수정**: TCL 스크립트(`run.tcl`)를 프로시저(`proc`) 기반으로 재구조화하여 시뮬레이션 종료 시 발생하던 에러를 해결했습니다.
- **DPI-C 호환성**: Python Integer Overflow 문제(MSB=1 데이터 처리)를 수정했습니다.
- **AHB 지원 강화**: AHB 시퀀스 및 드라이버 타이밍 이슈를 해결하고 검증을 완료했습니다.

---

## 사용 가이드

### 1. AI 기반 테스트 플랜 생성
`spec.txt`에 요구사항을 자연어로 작성하면, AI가 최적의 `config.yaml`을 제안합니다.

```bash
# 1. spec.txt 작성 (예: "AHB Slave 메모리 32비트...")
# 2. AI Planner 실행
python -m main.ai_planner --input ahb_spec.txt --output config.yaml

# 3. 생성된 config.yaml 확인 (필요시 수정)
```

### 2. 테스트벤치 생성 및 시뮬레이션
생성된 `config.yaml`을 사용하여 UVM 환경을 구축하고 시뮬레이션을 실행합니다.

```bash
# 1. Generator 실행 (PowerShell/CMD)
cd c:\git\UVM
python -m main.run --config config.yaml

# 2. Vivado 시뮬레이션 (Vivado TCL 콘솔)
cd output/sim
source run.tcl
```

### Key Config Structure (`config.yaml`)
```yaml
dut:
  parameters:        # VIP bitwidth configuration
    ADDR_WIDTH: 32
    DATA_WIDTH: 32
  dut_parameters: {}  # DUT instantiation parameters (empty if no params)

interfaces:
  - protocol: ahb
    port_map:
      HCLK: hclk      # KEY=DUT port, VALUE=VIP signal (Fixed Standard Name)
      HRESETN: hresetn
      HADDR: haddr
      # ...
```

---

## 자동 감지되는 항목 (설정 불필요)

| 항목 | 자동 감지 방법 | 위치 |
|------|---------------|------|
| GCC (MinGW) | `$XILINX_VIVADO/tps/mingw/*/` | Vivado 내장 |
| Python (DPI용) | `$XILINX_VIVADO/tps/win64/python-*/` | Vivado 내장 |
| UVM Library | `-L uvm` 옵션 | Vivado 내장 |

---

## ⚠️ 환경별 주의사항

### Windows vs Linux

| 항목 | Windows | Linux |
|------|---------|-------|
| DPI 라이브러리 | `libdpi.dll` | `libdpi.so` |
| 경로 구분자 | `\` | `/` |
| GCC 위치 | `mingw/*/win64.o/nt/bin/gcc.exe` | 시스템 GCC |

**현재 프로젝트는 Windows에서만 테스트되었습니다.**

---

## 권장 디렉토리 구조

```
프로젝트/
├── .gitignore           # Git 무시 파일
├── README.md            # 이 파일
├── config.yaml          # 프로젝트 설정 (AI 자동 생성 or 수동)
├── ahb_spec.txt         # [입력] AI Planner용 요구사항 명세
│
├── main/                # [Core] Python 코드
│   ├── run.py           # Generator 진입점
│   ├── ai_planner.py    # AI 매핑 에이전트
│   └── utils/           # 유틸리티 (Generator 등)
│
├── templates/           # [Core] Jinja2 템플릿
│   ├── vip/             # 표준 VIP 템플릿 (vip_signals.yaml 포함)
│   ├── sim/             # 시뮬레이션 스크립트
│   ├── tb/              # 테스트벤치 최상위
│   ├── test/            # UVM Test
│   └── dpi/             # DPI-C Wrapper
│
├── model/               # Python Golden Model
│   ├── ahb_model.py
│   └── apb_model.py
│
├── UVM/                 # DUT (사용자 제공)
│   ├── AHB/ahb_slave_mem.v
│   └── APB/apb_slave_mem.v
│
├── output/              # [자동 생성] 생성된 파일 (시뮬레이션 대상)
└── report/              # [자동 생성] 시뮬레이션 리포트
```

---

## 연락처

문제 발생 시 이 문서와 함께 다음 정보를 제공해주세요:
1. Vivado 버전
2. Python 버전
3. OS 버전
4. 에러 메시지 전체