module top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import apb_pkg::*;

    // Clock and Reset
    bit clk;
    bit rst_n;

    always #5 clk = ~clk; // 100MHz

    initial begin
        clk = 0;
        rst_n = 0;
        #20 rst_n = 1;
    end

    // Interface Instantiation
    apb_if #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) intf (
        .pclk(clk), 
        .presetn(rst_n)
    );

    // DUT Instantiation
    apb_slave_mem #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) dut (
        .pclk    (clk),
        .presetn (rst_n),
        
        .paddr   (intf.paddr),
        .psel    (intf.psel),
        .penable (intf.penable),
        .pwrite  (intf.pwrite),
        .pwdata  (intf.pwdata),
        .pready  (intf.pready),
        .prdata  (intf.prdata),
        .pslverr (intf.pslverr)
    );

    initial begin
        // Set Interface to Config DB
        // Key: "vif", Value: intf instance
        uvm_config_db#(virtual apb_if#(32, 32))::set(null, "*", "vif", intf);

        // Run Test
        // For now, we will run a dummy test or a base test if it exists. 
        // We haven't created a specific test class yet, so this might fail at runtime if run_test() is called with expectation.
        // But for structure verification, this is enough.
        run_test("uvm_test_top"); 
    end

endmodule
