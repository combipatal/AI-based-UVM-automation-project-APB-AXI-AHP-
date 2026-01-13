package apb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Forward Typedefs if needed
    // ...

    // DPI Imports for Scoreboard
    import "DPI-C" context function void dpi_mem_write(int addr, int data);
    import "DPI-C" context function int  dpi_mem_read(int addr);

    // Include VIP Components
    // Note: These will be templated files, but here we include the file names.
    // In a real generation scenario, we might concatenate them or include them.
    // However, for this structure, we assume they are generated into this package scope.

    `include "apb_seq_item.sv"
    `include "apb_base_seq.sv"
    `include "apb_driver.sv"
    `include "apb_monitor.sv"
    `include "apb_agent.sv"
    `include "apb_scoreboard.sv"

endpackage
