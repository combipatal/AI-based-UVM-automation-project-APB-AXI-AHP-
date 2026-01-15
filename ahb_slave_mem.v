module ahb_slave_mem (
    //* GLOBAL SIGNAL
    input           HCLK,
    input           HRESETn,
    //* MASTER SIGNAL
    input   [31:0]  HADDR,  // 주소버스
    input   [1:0]   HTRANS, // 전송타입 : IDLE, BUSY, NONSEQ, SEQ
    input           HWRITE, // 1 = write, 0 = read
    input   [2:0]   HSIZE,  // 전송 크기 (byte etc..)
    input   [31:0]  HWDATA, // 쓰기 데이터 버스
    //* SLAVE SIGNAL
    output  [31:0]  HRDATA, // 읽기 데이터 버스
    output          HREADY, // 1 = 전송완료, 0 = 대기
    output          HRESP,  // 응답신호 (0 = OKAY, 1 = ERROR)
    //* DECODER SIGNAL
    input           HSELx   // Decoder가 Slave를 선택

);   

//==============================================================================
// HTRANS 정의 (AHB-Lite Protocol)
//==============================================================================
localparam IDLE   = 2'b00;
localparam BUSY   = 2'b01;
localparam NONSEQ = 2'b10;
localparam SEQ    = 2'b11;

//==============================================================================
// HRESP 정의 (AHB-Lite: 1-bit)
//==============================================================================
localparam OKAY  = 1'b0;
localparam ERROR = 1'b1;

//==============================================================================
// 내부 신호 선언
//==============================================================================
reg [31:0] memory [0:1023];  // 4KB 메모리 (1024 x 32bit)
reg [31:0] HRDATA_reg;
reg        HREADY_reg;
reg        HRESP_reg;

// Address Phase에서 받은 신호들을 Data Phase에서 사용하기 위해 저장
reg [31:0] addr_latch;
reg        write_latch;
reg [2:0]  size_latch;
reg        sel_latch;

//==============================================================================
// Output 할당
//==============================================================================
assign HRDATA = HRDATA_reg;
assign HREADY = HREADY_reg;
assign HRESP  = HRESP_reg;

//==============================================================================
// Address Phase: 주소 및 제어 신호 래치
//==============================================================================
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        addr_latch  <= 32'h0;
        write_latch <= 1'b0;
        size_latch  <= 3'b0;
        sel_latch   <= 1'b0;
    end else begin
        // Slave 동작 조건:
        // 1. HSELx = 1      (나를 선택했나?)
        // 2. HTRANS != IDLE (유효한 전송인가?)
        if (HSELx && (HTRANS != IDLE) && (HTRANS != BUSY)) begin
            addr_latch  <= HADDR;
            write_latch <= HWRITE;
            size_latch  <= HSIZE;
            sel_latch   <= 1'b1;
        end else begin
            sel_latch <= 1'b0;
        end
    end
end

//==============================================================================
// Data Phase: 실제 Write/Read 동작
//==============================================================================
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HREADY_reg <= 1'b1;   // 기본적으로 항상 준비됨
        HRESP_reg  <= OKAY;
        HRDATA_reg <= 32'h0;

        // 메모리 초기화
        integer i;
        for (i = 0; i < 1024; i = i + 1) begin
            memory[i] <= 32'h0;
        end
    end else begin
        // 기본 응답: OKAY (AHB-Lite는 에러 미지원)
        HRESP_reg  <= OKAY;
        HREADY_reg <= 1'b1;

        // Data Phase 동작 조건:
        // 1. sel_latch = 1   (이전 사이클에 선택됨)
        // 2. HREADY = 1      (Master가 준비됨)
        if (sel_latch && HREADY_reg) begin
            if (write_latch) begin
                //==========================================================
                // WRITE 동작
                //==========================================================
                // 주소 범위 체크 (4KB = 0x0000 ~ 0x0FFF)
                if (addr_latch[31:12] == 20'h0) begin
                    case (size_latch)
                        3'b000: begin  // Byte (8-bit)
                            case (addr_latch[1:0])
                                2'b00: memory[addr_latch[11:2]][7:0]   <= HWDATA[7:0];
                                2'b01: memory[addr_latch[11:2]][15:8]  <= HWDATA[7:0];
                                2'b10: memory[addr_latch[11:2]][23:16] <= HWDATA[7:0];
                                2'b11: memory[addr_latch[11:2]][31:24] <= HWDATA[7:0];
                            endcase
                        end
                        3'b001: begin  // Halfword (16-bit)
                            if (addr_latch[1] == 1'b0)
                                memory[addr_latch[11:2]][15:0]  <= HWDATA[15:0];
                            else
                                memory[addr_latch[11:2]][31:16] <= HWDATA[15:0];
                        end
                        3'b010: begin  // Word (32-bit)
                            memory[addr_latch[11:2]] <= HWDATA;
                        end
                        default: begin
                            HRESP_reg <= ERROR;  // 지원하지 않는 크기
                        end
                    endcase
                end else begin
                    HRESP_reg <= ERROR;  // 주소 범위 초과
                end
            end else begin
                //==========================================================
                // READ 동작
                //==========================================================
                if (addr_latch[31:12] == 20'h0) begin
                    case (size_latch)
                        3'b000: begin  // Byte (8-bit)
                            case (addr_latch[1:0])
                                2'b00: HRDATA_reg <= {24'h0, memory[addr_latch[11:2]][7:0]};
                                2'b01: HRDATA_reg <= {24'h0, memory[addr_latch[11:2]][15:8]};
                                2'b10: HRDATA_reg <= {24'h0, memory[addr_latch[11:2]][23:16]};
                                2'b11: HRDATA_reg <= {24'h0, memory[addr_latch[11:2]][31:24]};
                            endcase
                        end
                        3'b001: begin  // Halfword (16-bit)
                            if (addr_latch[1] == 1'b0)
                                HRDATA_reg <= {16'h0, memory[addr_latch[11:2]][15:0]};
                            else
                                HRDATA_reg <= {16'h0, memory[addr_latch[11:2]][31:16]};
                        end
                        3'b010: begin  // Word (32-bit)
                            HRDATA_reg <= memory[addr_latch[11:2]];
                        end
                        default: begin
                            HRESP_reg  <= ERROR;  // 지원하지 않는 크기
                            HRDATA_reg <= 32'h0;
                        end
                    endcase
                end else begin
                    HRESP_reg  <= ERROR;  // 주소 범위 초과
                    HRDATA_reg <= 32'h0;
                end
            end
        end
    end
end




endmodule