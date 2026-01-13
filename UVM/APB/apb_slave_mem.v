module apb_slave_mem #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter RAM_DEPTH  = 256
)(
    input  wire                  pclk,
    input  wire                  presetn,
    input  wire [ADDR_WIDTH-1:0] paddr,
    input  wire                  psel,
    input  wire                  penable,
    input  wire                  pwrite,
    input  wire [DATA_WIDTH-1:0] pwdata,
    output reg                   pready,
    output reg  [DATA_WIDTH-1:0] rdata,
    output wire                  pslverr
);

    // Memory Array
    reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];

    // Address decoding
    wire [ADDR_WIDTH-1:0] word_addr;
    assign word_addr = paddr >> 2;

    // Local Signals
    wire valid_access = psel && penable;
    assign pslverr = 1'b0;

    // [Write Operation] - 동기식 (유지)
    // Write는 마스터가 이미 데이터를 안정적으로 주고 있으므로 posedge에서 캡처해도 됩니다.
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            // Reset logic if needed
        end else if (valid_access && pwrite) begin  // pready 체크 제거!
            if (word_addr < RAM_DEPTH) begin
                mem[word_addr] <= pwdata;
            end
        end
    end

    // [Read Operation] - **수정됨: 조합 회로(Combinational)**
    // 주소가 주어지면 즉시 데이터를 출력해야 마스터가 클럭 에지에서 캡처 가능합니다.
    always @(*) begin
        if (valid_access && !pwrite) begin
            if (word_addr < RAM_DEPTH) begin
                rdata = mem[word_addr];
            end else begin
                rdata = {DATA_WIDTH{1'b0}}; // Out of range
            end
        end else begin
            rdata = {DATA_WIDTH{1'b0}}; // Default value
        end
    end

    // [Ready Generation]
    // 0 Wait State 구현
    always @(*) begin
        if (psel && penable) begin
            pready = 1'b1;
        end else begin
            pready = 1'b0;
        end
    end

endmodule