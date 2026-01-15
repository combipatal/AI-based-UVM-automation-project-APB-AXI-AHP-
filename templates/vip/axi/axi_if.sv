
interface axi_if #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) (
    input bit aclk, 
    input bit aresetn
);

    // Write Address Channel
    logic [ADDR_WIDTH-1:0] awaddr;
    logic                  awvalid;
    logic                  awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic                  wvalid;
    logic                  wready;

    // Write Response Channel
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // Read Address Channel
    logic [ADDR_WIDTH-1:0] araddr;
    logic                  arvalid;
    logic                  arready;

    // Read Data Channel
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0]            rresp;
    logic                  rvalid;
    logic                  rready;

    // Modports
    modport master (
        input  aclk, aresetn, 
        output awaddr, awvalid, input awready,
        output wdata, wstrb, wvalid, input wready,
        input  bresp, bvalid, output bready,
        output araddr, arvalid, input arready,
        input  rdata, rresp, rvalid, output rready
    );

    modport slave (
        input  aclk, aresetn, 
        input  awaddr, awvalid, output awready,
        input  wdata, wstrb, wvalid, output wready,
        output bresp, bvalid, input  bready,
        input  araddr, arvalid, output arready,
        output rdata, rresp, rvalid, input  rready
    );

    modport monitor (
        input aclk, aresetn,
        input awaddr, awvalid, awready,
        input wdata, wstrb, wvalid, wready,
        input bresp, bvalid, bready,
        input araddr, arvalid, arready,
        input rdata, rresp, rvalid, rready
    );

endinterface
