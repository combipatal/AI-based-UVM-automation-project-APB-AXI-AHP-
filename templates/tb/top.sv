module top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    // Import VIP Packages
    // Import Testbench Package
    import tb_pkg::*;

    // Import DPI-C Wrapper
    import "DPI-C" context function void dpi_mem_write(int addr, int data);
    import "DPI-C" context function int  dpi_mem_read(int addr);

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
    {% for intf in interfaces %}
    {{ intf.type }} {{ intf.name }}(.{{ intf.clock }}(clk), .{{ intf.reset }}(rst_n));
    {% endfor %}

    // DUT Instantiation
    {{ dut_name }} #(
        .ADDR_WIDTH({{ addr_width }}),
        .DATA_WIDTH({{ data_width }})
    ) dut (
        // Connect Interface Signals
        {% for port_map in port_maps %}
        .{{ port_map.dut_port }} ({{ port_map.intf_sig }}){% if not loop.last %},{% endif %}
        {% endfor %}
    );

    initial begin
        // Set Interface to Config DB
        {% for intf in interfaces %}
        // Scope: Include agent and all its children (driver, monitor, etc.)
        uvm_config_db#(virtual {{ intf.type }})::set(null, "uvm_test_top.env.{{ intf.name }}*", "vif", {{ intf.name }});
        {% endfor %}

        // Run Test
        run_test("{{ default_test }}");
    end

endmodule
