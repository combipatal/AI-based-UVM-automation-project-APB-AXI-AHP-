class apb_scoreboard #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_scoreboard;

    `uvm_component_param_utils(apb_scoreboard#(ADDR_WIDTH, DATA_WIDTH))

    // Analysis Import (Connect to Monitor)
    uvm_analysis_imp #(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH), apb_scoreboard#(ADDR_WIDTH, DATA_WIDTH)) item_collected_export;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
    endfunction

    // Implement write method for analysis imp
    virtual function void write(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH) item);
        int expected_data;
        
        if (item.write) begin
            // WRITE Operation
            `uvm_info("SCB", $sformatf("WRITE: Addr=0x%0h Data=0x%0h", item.addr, item.data), UVM_MEDIUM)
            $display("[SCB_WRITE] Calling Python: Addr=0x%0h Data=0x%0h", item.addr, item.data);
            // Call Python Model
            dpi_mem_write(item.addr, item.data);
        end else begin
            // READ Operation
            // 1. Get Expected Data from Python
            $display("[SCB_READ] Calling Python for Addr=0x%0h", item.addr);
            expected_data = dpi_mem_read(item.addr);
            $display("[SCB_READ] Python returned: 0x%0h", expected_data);
            
            // 2. Compare with Actual Data (item.data or item.rdata depending on seq_item definition)
            // Assuming 'data' holds the read data in monitoring context, or 'rdata'
            // Let's check apb_seq_item.sv -> usually 'data' is payload. 
            // If monitored item puts read data in 'data', use 'data'.
            // In typical APB mon, we capture PRDATA into item.data or item.rdata.
            
            `uvm_info("SCB", $sformatf("READ: Addr=0x%0h | DUT=0x%0h vs Model=0x%0h", 
                                       item.addr, item.rdata, expected_data), UVM_MEDIUM)

            if (item.rdata !== expected_data) begin
                `uvm_error("SCB_MISMATCH", $sformatf("Data Mismatch! Addr=0x%0h DUT=0x%0h Exp=0x%0h", 
                                                     item.addr, item.rdata, expected_data))
            end else begin
                `uvm_info("SCB_MATCH", "Read Data Match!", UVM_HIGH)
            end
        end
    endfunction

endclass
