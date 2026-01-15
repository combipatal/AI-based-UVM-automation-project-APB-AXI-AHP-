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
reg        HREADY_reg;
reg        HRESP_reg;

// Address Phase에서 받은 신호들을 Data Phase에서 사용하기 위해 저장
reg [31:0] addr_latch;
reg        write_latch;
reg [2:0]  size_latch;
reg        sel_latch;

// 메모리 초기화용 인덱스
integer i;

//==============================================================================
// Output 할당
//==============================================================================
assign HREADY = HREADY_reg;
assign HRESP  = HRESP_reg;

//==============================================================================
// 메모리 초기화 (시뮬레이션 전용)
//==============================================================================
initial begin
    for (i = 0; i < 1024; i = i + 1) begin
        memory[i] = 32'h0;
    end
end

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
        // AHB-Lite Slave 동작 조건:
        // 1. HSELx = 1       (Decoder가 이 Slave를 선택)
        // 2. HTRANS = NONSEQ 또는 SEQ (유효한 전송)
        // Note: IDLE/BUSY는 무시 (데이터 전송 없음)
        if (HSELx && (HTRANS == NONSEQ || HTRANS == SEQ)) begin
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
// Data Phase: Write 동작 (Sequential)
//==============================================================================
always @(posedge HCLK or negedge HRESETn) begin
    if (!HRESETn) begin
        HREADY_reg <= 1'b1;
        HRESP_reg  <= OKAY;
    end else begin
        HRESP_reg  <= OKAY;
        HREADY_reg <= 1'b1;

        if (sel_latch && write_latch) begin
            if (addr_latch[31:12] == 20'h0) begin
                case (size_latch)
                    3'b000: begin
                        case (addr_latch[1:0])
                            2'b00: memory[addr_latch[11:2]][7:0]   <= HWDATA[7:0];
                            2'b01: memory[addr_latch[11:2]][15:8]  <= HWDATA[7:0];
                            2'b10: memory[addr_latch[11:2]][23:16] <= HWDATA[7:0];
                            2'b11: memory[addr_latch[11:2]][31:24] <= HWDATA[7:0];
                        endcase
                    end
                    3'b001: begin
                        if (addr_latch[1] == 1'b0)
                            memory[addr_latch[11:2]][15:0]  <= HWDATA[15:0];
                        else
                            memory[addr_latch[11:2]][31:16] <= HWDATA[15:0];
                    end
                    3'b010: begin
                        memory[addr_latch[11:2]] <= HWDATA;
                    end
                    default: HRESP_reg <= ERROR;
                endcase
            end else begin
                HRESP_reg <= ERROR;
            end
        end
    end
end

//==============================================================================
// Read Data: Combinational logic (조합 논리)
//==============================================================================
reg [31:0] HRDATA_comb;

always @(*) begin
    HRDATA_comb = 32'h0;
    
    if (sel_latch && !write_latch) begin
        if (addr_latch[31:12] == 20'h0) begin
            case (size_latch)
                3'b000: begin
                    case (addr_latch[1:0])
                        2'b00: HRDATA_comb = {24'h0, memory[addr_latch[11:2]][7:0]};
                        2'b01: HRDATA_comb = {24'h0, memory[addr_latch[11:2]][15:8]};
                        2'b10: HRDATA_comb = {24'h0, memory[addr_latch[11:2]][23:16]};
                        2'b11: HRDATA_comb = {24'h0, memory[addr_latch[11:2]][31:24]};
                    endcase
                end
                3'b001: begin
                    if (addr_latch[1] == 1'b0)
                        HRDATA_comb = {16'h0, memory[addr_latch[11:2]][15:0]};
                    else
                        HRDATA_comb = {16'h0, memory[addr_latch[11:2]][31:16]};
                end
                3'b010: begin
                    HRDATA_comb = memory[addr_latch[11:2]];
                end
                default: HRDATA_comb = 32'h0;
            endcase
        end
    end
end

assign HRDATA = HRDATA_comb;




endmodule