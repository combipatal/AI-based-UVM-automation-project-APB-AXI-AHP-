package ahb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    //==========================================================================
    // DPI Imports for Scoreboard (Python Golden Model)
    //==========================================================================
    import "DPI-C" context function void dpi_mem_write(int addr, int data);
    import "DPI-C" context function int  dpi_mem_read(int addr);

    //==========================================================================
    // Include VIP Components
    //==========================================================================
    `include "ahb_seq_item.sv"
    `include "ahb_base_seq.sv"
    `include "ahb_driver.sv"
    `include "ahb_monitor.sv"
    `include "ahb_agent.sv"
    `include "ahb_scoreboard.sv"

endpackage
