interface ahb_if #(
    parameter int ADDR_WIDTH = {{ ADDR_WIDTH }},
    parameter int DATA_WIDTH = {{ DATA_WIDTH }}
)(
    input logic hclk,
    input logic hresetn
);

    //==========================================================================
    // AHB-Lite Signal Definitions
    //==========================================================================
    
    // Address & Control (Address Phase)
    logic [ADDR_WIDTH-1:0] haddr;
    logic [1:0]            htrans;   // Transfer type: IDLE, BUSY, NONSEQ, SEQ
    logic                  hwrite;   // 1 = Write, 0 = Read
    logic [2:0]            hsize;    // Transfer size: 000=Byte, 001=Halfword, 010=Word
    logic [2:0]            hburst;   // Burst type (AHB-Lite: usually SINGLE)
    logic [3:0]            hprot;    // Protection control
    logic                  hsel;     // Slave select
    
    // Data (Data Phase)
    logic [DATA_WIDTH-1:0] hwdata;   // Write data
    logic [DATA_WIDTH-1:0] hrdata;   // Read data
    
    // Transfer Response
    logic                  hready;   // Transfer done (1 = ready)
    logic                  hresp;    // Transfer response (0 = OKAY, 1 = ERROR)

    //==========================================================================
    // HTRANS Encoding
    //==========================================================================
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        BUSY   = 2'b01,
        NONSEQ = 2'b10,
        SEQ    = 2'b11
    } htrans_t;

    //==========================================================================
    // HSIZE Encoding
    //==========================================================================
    typedef enum logic [2:0] {
        BYTE      = 3'b000,   // 8-bit
        HALFWORD  = 3'b001,   // 16-bit
        WORD      = 3'b010,   // 32-bit
        DWORD     = 3'b011,   // 64-bit
        WORD4     = 3'b100,   // 128-bit
        WORD8     = 3'b101,   // 256-bit
        WORD16    = 3'b110,   // 512-bit
        WORD32    = 3'b111    // 1024-bit
    } hsize_t;

    //==========================================================================
    // HBURST Encoding
    //==========================================================================
    typedef enum logic [2:0] {
        SINGLE = 3'b000,
        INCR   = 3'b001,
        WRAP4  = 3'b010,
        INCR4  = 3'b011,
        WRAP8  = 3'b100,
        INCR8  = 3'b101,
        WRAP16 = 3'b110,
        INCR16 = 3'b111
    } hburst_t;

    //==========================================================================
    // HRESP Encoding (AHB-Lite: 1-bit)
    //==========================================================================
    typedef enum logic {
        OKAY  = 1'b0,
        ERROR = 1'b1
    } hresp_t;

    //==========================================================================
    // Modport for Driver (Master)
    //==========================================================================
    modport master (
        output haddr, htrans, hwrite, hsize, hburst, hprot, hsel, hwdata,
        input  hrdata, hready, hresp,
        input  hclk, hresetn
    );

    //==========================================================================
    // Modport for Monitor (Observer)
    //==========================================================================
    modport monitor (
        input haddr, htrans, hwrite, hsize, hburst, hprot, hsel, hwdata,
        input hrdata, hready, hresp,
        input hclk, hresetn
    );

    //==========================================================================
    // Modport for Slave
    //==========================================================================
    modport slave (
        input  haddr, htrans, hwrite, hsize, hburst, hprot, hsel, hwdata,
        output hrdata, hready, hresp,
        input  hclk, hresetn
    );

endinterface
