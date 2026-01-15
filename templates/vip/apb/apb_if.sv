interface apb_if #(
    parameter int ADDR_WIDTH = {{ ADDR_WIDTH }},
    parameter int DATA_WIDTH = {{ DATA_WIDTH }}
)(
    input logic pclk,
    input logic presetn
);

    logic [ADDR_WIDTH-1:0] paddr;
    logic                  psel;
    logic                  penable;
    logic                  pwrite;
    logic [DATA_WIDTH-1:0] pwdata;
    logic                  pready;
    logic [DATA_WIDTH-1:0] prdata;
    logic                  pslverr;

    // Modport for Driver (Master)
    modport master (
        output paddr, psel, penable, pwrite, pwdata,
        input  pready, prdata, pslverr,
        input  pclk, presetn
    );

    // Modport for Monitor (Observer)
    modport monitor (
        input paddr, psel, penable, pwrite, pwdata,
        input pready, prdata, pslverr,
        input pclk, presetn
    );

endinterface
