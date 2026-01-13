module axi_slave_ctrl #(
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
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output wire                  s_axi_rvalid,
    input  wire                  s_axi_rready,

    // Memory Interface
    output wire                  mem_en,
    output wire                  mem_we,
    output wire [ADDR_WIDTH-1:0] mem_addr,
    output wire [DATA_WIDTH-1:0] mem_wdata
);

    // Internal State Registers
    reg aw_en;
    reg [ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready_r;
    reg axi_wready_r;
    reg [1:0] axi_bresp_r;
    reg axi_bvalid_r;
    reg [ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready_r;
    reg [DATA_WIDTH-1:0] axi_rdata_r;
    reg [1:0] axi_rresp_r;
    reg axi_rvalid_r;

    // Word Address Calculation
    localparam integer ADDR_LSB = (DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = $clog2(RAM_DEPTH);

    // I/O Assignments (directly from internal registers)
    assign s_axi_awready = axi_awready_r;
    assign s_axi_wready  = axi_wready_r;
    assign s_axi_bresp   = axi_bresp_r;
    assign s_axi_bvalid  = axi_bvalid_r;
    assign s_axi_arready = axi_arready_r;
    assign s_axi_rdata   = axi_rdata_r;
    assign s_axi_rresp   = axi_rresp_r;
    assign s_axi_rvalid  = axi_rvalid_r;

    // =========================================================================
    // MEMORY CONTROL - DIRECTLY MIRRORS ORIGINAL axi_slave_mem.v TIMING
    // =========================================================================
    // Write: When both ready signals ARE HIGH (this is Cycle T+1 after handshake)
    //        At this point, axi_awaddr holds the VALID captured address from Cycle T.
    assign mem_we    = axi_awready_r && axi_wready_r;
    assign mem_wdata = s_axi_wdata;
    
    // Read: When arready is HIGH and arvalid is still asserted (Cycle T+1)
    //       At this point, axi_araddr holds the VALID captured address.
    wire read_phase = axi_arready_r && s_axi_arvalid && ~axi_rvalid_r;
    
    // Memory Enable and Address Mux
    assign mem_en   = mem_we || read_phase;
    assign mem_addr = mem_we ? axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1 : ADDR_LSB] :
                               axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1 : ADDR_LSB];

    // =========================================================================
    // WRITE LOGIC - Matches original axi_slave_mem.v exactly
    // =========================================================================
    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_awready_r <= 1'b0;
            aw_en         <= 1'b1;
            axi_awaddr    <= 0;
            axi_wready_r  <= 1'b0;
            axi_bvalid_r  <= 0;
            axi_bresp_r   <= 2'b00;
        end 
        else begin
            // 1. Write Address Handshake
            if (~axi_awready_r && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                axi_awready_r <= 1'b1;
                aw_en         <= 1'b0;
                axi_awaddr    <= s_axi_awaddr;  // Capture address HERE
            end else if (s_axi_bready && axi_bvalid_r) begin
                aw_en         <= 1'b1;
                axi_awready_r <= 1'b0;
            end else begin
                axi_awready_r <= 1'b0;
            end

            // 2. Write Data Handshake
            if (~axi_wready_r && s_axi_wvalid && s_axi_awvalid && aw_en) begin
                axi_wready_r <= 1'b1;
            end else begin
                axi_wready_r <= 1'b0;
            end

            // 3. Write Response
            if (axi_awready_r && s_axi_awvalid && axi_wready_r && s_axi_wvalid && ~axi_bvalid_r) begin
                axi_bvalid_r <= 1'b1;
                axi_bresp_r  <= 2'b00; // OKAY
            end else begin
                if (s_axi_bready && axi_bvalid_r) begin
                    axi_bvalid_r <= 1'b0;
                end
            end
            
            // NOTE: Memory Write is handled combinatorially above (mem_we, mem_addr)
            // The actual write happens in simple_ram at the NEXT clock edge
            // when mem_we=1 and mem_addr=axi_awaddr (which was captured in step 1)
        end
    end

    // =========================================================================
    // READ LOGIC - Matches original axi_slave_mem.v exactly
    // =========================================================================
    always @(posedge aclk) begin
        if (aresetn == 1'b0) begin
            axi_arready_r <= 1'b0;
            axi_araddr    <= 0;
            axi_rvalid_r  <= 0;
            axi_rresp_r   <= 0;
            axi_rdata_r   <= 0;
        end 
        else begin
            // 1. Read Address Handshake
            if (~axi_arready_r && s_axi_arvalid) begin
                axi_arready_r <= 1'b1;
                axi_araddr    <= s_axi_araddr;  // Capture address HERE
            end else begin
                axi_arready_r <= 1'b0;
            end

            // 2. Read Data & Handshake
            // This triggers in Cycle T+1 when arready IS HIGH (was set in Cycle T)
            if (axi_arready_r && s_axi_arvalid && ~axi_rvalid_r) begin
                axi_rvalid_r <= 1'b1;
                axi_rresp_r  <= 2'b00; // OKAY
                // mem_rdata should be valid NOW because:
                // - axi_araddr was captured in Cycle T
                // - mem_addr = axi_araddr is driven combinatorially
                // - simple_ram has combinatorial read (assign rdata = mem[addr])
                axi_rdata_r  <= mem_rdata;
            end else if (axi_rvalid_r && s_axi_rready) begin
                axi_rvalid_r <= 1'b0;
            end
        end
    end

endmodule
