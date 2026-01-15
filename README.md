# UVM Testbench Generator - 환경 설정 및 주의사항
-- AHB 추가 예정
-- coverage 추가 예정
## 1. 프로젝트 개요 (Project Overview)

**AI 기반 UVM 자동화 솔루션**
이 프로젝트는 **Jinja2 템플릿 엔진**과 **Large Language Model (LLM)**을 결합하여 UVM 테스트벤치를 자동으로 생성하는 로컬 Python 툴입니다. 반복적인 코딩 작업을 줄이고, 검증 로직 구현에 집중할 수 있도록 돕습니다.

### 핵심 철학 (Core Philosophy)
- **Standard Protocol (APB, AXI 등)**: 무조건 **검증된 VIP 템플릿**을 재사용하여 신뢰성을 확보합니다.
- **Custom Protocol**: 사용자의 자연어 명세를 AI가 **코드(SystemVerilog)로 번역(Translation)**하여 검증 로직을 생성합니다.
- **Verification = Golden Model**: Python으로 작성된 알고리즘을 **DPI-C**로 연결하여 Scoreboard에서 정밀하게 검증합니다.

### 주요 시스템 구조
1.  **입력**: RTL 명세, 프로토콜 선택, Python Golden Model.
2.  **생성기 (Generator)**:
    *   **Jinja2**: DPI-C Wrapper, SV Import 등 정형화된 코드 자동 생성.
    *   **AI Agent**: Interface 매핑 및 커스텀 로직 번역.
3.  **출력**: 실행 가능한 UVM 환경 (`tb`, `env`, `agents`, `sim` scripts).

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

## 🚀 새로운 기능 (2026.01 업데이트)

### 1. AI 기반 테스트 플랜 자동 생성
`spec.txt`에 자연어로 요구사항을 적으면, AI가 `config.yaml`을 자동으로 생성합니다.

```bash
# 1. spec.txt 작성 (예: "AXI4 Lite 메모리 테스트...")
# 2. AI Planner 실행
python -m main.ai_planner --input spec.txt

# 3. 생성된 config.yaml 확인 및 테스트벤치 생성
python -m main.run --config config.yaml
```

### 2. 멀티 프로토콜 지원 (APB, AXI, etc.)
코드를 수정할 필요 없이 설정만으로 다양한 프로토콜을 테스트할 수 있습니다.

**사용 방법 (예: AXI 추가):**
1. `templates/vip/axi/` 폴더에 VIP 템플릿(driver, monitor 등) 추가
2. `model/axi_model.py` 추가 (Golden Model)
3. `config.yaml` 설정:
   ```yaml
   interfaces:
     - name: vif_0
       protocol: axi
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

Linux 사용 시 `run.tcl`의 다음 부분 수정 필요:
```tcl
# Windows 전용 코드 (수정 필요)
set gcc_exe "$mingw_dir/win64.o/nt/bin/gcc.exe"
```

---

### Vivado 버전 차이

#### Python 버전
- Vivado 2023.x: Python 3.8
- Vivado 2024.x: Python 3.11
- Vivado 2025.x: Python 3.13

**자동 감지하므로 일반적으로 문제 없음**

#### DPI 빌드 방식
현재 `run.tcl`은 `xsc` 대신 **수동 GCC 빌드**를 사용합니다.
이는 Windows에서 `xsc`의 경로 문제를 우회하기 위함입니다.

---

### DUT 경로 설정

`config.yaml`에서 DUT 경로 지정:
```yaml
dut:
  files:
    - ../../UVM/APB/apb_slave_mem.v  # 상대 경로
```

**주의**: 경로는 `output/sim/` 기준 상대 경로입니다.

---

## 프로젝트 실행 순서

```bash
# 1. 필수 패키지 설치
pip install pyyaml jinja2

# 2. Generator 실행 (PowerShell/CMD)
cd c:\git\UVM
python -m main.run --config config.yaml

# 3. Vivado 시뮬레이션 (Vivado TCL 콘솔)
cd output/sim
source run.tcl
```

---

## 문제 해결

### 1. `XILINX_VIVADO not set`
```powershell
# Windows PowerShell에서 설정
$env:XILINX_VIVADO = "C:\Xilinx\2025.1\Vivado"
```

### 2. `Python.h not found`
Vivado 내장 Python에 헤더가 없는 경우 발생.
→ Vivado 재설치 또는 전체 설치 옵션 선택

### 3. `ModuleNotFoundError: apb_model`
`model/apb_model.py`가 `output/sim/`으로 복사되지 않은 경우.
→ `run.tcl`이 자동 복사하지만, 수동 확인 필요

### 4. DPI 로드 실패
필요한 DLL이 누락된 경우:
```
libpython3.dll
libgcc_s_seh-1.dll
libwinpthread-1.dll
```
→ `run.tcl`이 자동 복사하지만, Vivado 버전에 따라 다를 수 있음

---

## 권장 디렉토리 구조

```
프로젝트/
├── .gitignore           # Git 무시 파일
├── README.md            # 이 파일
├── config.yaml          # 프로젝트 설정
│
├── main/                # Generator Python 코드
│   └── run.py
│
├── templates/           # VIP 템플릿
│   ├── vip/apb/         # APB VIP
│   ├── sim/             # 시뮬레이션 스크립트
│   └── tb/              # 테스트벤치
│
├── model/               # Python Golden Model
│   └── apb_model.py
│
├── UVM/APB/             # DUT (사용자 제공)
│   └── apb_slave_mem.v
│
├── output/              # [자동 생성] 생성된 파일
└── report/              # [자동 생성] 시뮬레이션 리포트
```

---

## 연락처

문제 발생 시 이 문서와 함께 다음 정보를 제공해주세요:
1. Vivado 버전
2. Python 버전
3. OS 버전
4. 에러 메시지 전체
