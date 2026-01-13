module axi_slave_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter RAM_DEPTH  = 256
)(
    // AXI Global
    input  wire                  aclk,
    input  wire                  aresetn,

    // Write Address Channel
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,

    // Write Response Channel
    output wire [1:0]            s_axi_bresp,
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,

    // Read Address Channel
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,

    // Read Data Channel
    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready
);

    // Internal Signals
    wire                  mem_en;
    wire                  mem_we;
    wire [ADDR_WIDTH-1:0] mem_addr; // Full width from ctrl, but RAM takes smaller width usually
    wire [DATA_WIDTH-1:0] mem_wdata;
    wire [DATA_WIDTH-1:0] mem_rdata;
    
    // Address Width Calculation for RAM
    localparam integer OPT_MEM_ADDR_BITS = $clog2(RAM_DEPTH);
    // Ctrl outputs optimized address or full? 
    // In my ctrl code: output reg [ADDR_WIDTH-1:0] mem_addr;
    // but assigned: axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1 : ADDR_LSB]
    // So it outputs the INDEX. The width should be OPT_MEM_ADDR_BITS.
    // Let's adjust wire width or let Verilog truncate.
    
    // Instantiate Controller
    axi_slave_ctrl #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .RAM_DEPTH(RAM_DEPTH)
    ) u_ctrl (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .mem_rdata(mem_rdata),
        .mem_en(mem_en),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata)
    );

    // Instantiate Memory
    // Note: addr width mismatch handling.
    // mem_addr from Ctrl is ADDR_WIDTH bits wide (per definition), but content is index.
    simple_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(OPT_MEM_ADDR_BITS), // Match depth
        .RAM_DEPTH(RAM_DEPTH)
    ) u_mem (
        .clk(aclk),
        .en(mem_en),
        .we(mem_we),
        .addr(mem_addr[OPT_MEM_ADDR_BITS-1:0]), // Connect only LSBs
        .wdata(mem_wdata),
        .rdata(mem_rdata)
    );

endmodule
