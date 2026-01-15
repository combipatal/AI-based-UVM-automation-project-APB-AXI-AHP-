class ahb_scoreboard #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_scoreboard;

    `uvm_component_param_utils(ahb_scoreboard#(ADDR_WIDTH, DATA_WIDTH))

    //==========================================================================
    // Analysis Import (Connect to Monitor)
    //==========================================================================
    uvm_analysis_imp #(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH), ahb_scoreboard#(ADDR_WIDTH, DATA_WIDTH)) item_collected_export;

    //==========================================================================
    // Statistics
    //==========================================================================
    int unsigned write_count;
    int unsigned read_count;
    int unsigned match_count;
    int unsigned mismatch_count;

    //==========================================================================
    // Constructor
    //==========================================================================
    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
        write_count    = 0;
        read_count     = 0;
        match_count    = 0;
        mismatch_count = 0;
    endfunction

    //==========================================================================
    // Write Method (Analysis Port Callback)
    //==========================================================================
    virtual function void write(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) item);
        int expected_data;
        
        if (item.write) begin
            //==================================================================
            // WRITE Operation
            //==================================================================
            write_count++;
            `uvm_info("SCB", $sformatf("WRITE: Addr=0x%0h Data=0x%0h Size=%0d", 
                                        item.addr, item.data, item.size), UVM_MEDIUM)
            
            $display("[SCB_WRITE] Calling Python Model: Addr=0x%0h Data=0x%0h", 
                     item.addr, item.data);
            
            // Call Python Golden Model via DPI-C
            dpi_mem_write(item.addr, item.data);
            
        end else begin
            //==================================================================
            // READ Operation
            //==================================================================
            read_count++;
            
            // Get expected data from Python Golden Model
            $display("[SCB_READ] Calling Python Model for Addr=0x%0h", item.addr);
            expected_data = dpi_mem_read(item.addr);
            $display("[SCB_READ] Python returned: 0x%0h", expected_data);
            
            `uvm_info("SCB", $sformatf("READ: Addr=0x%0h | DUT=0x%0h vs Model=0x%0h", 
                                        item.addr, item.rdata, expected_data), UVM_MEDIUM)

            // Compare DUT vs Golden Model
            if (item.rdata !== expected_data) begin
                mismatch_count++;
                `uvm_error("SCB_MISMATCH", $sformatf("Data Mismatch! Addr=0x%0h DUT=0x%0h Exp=0x%0h", 
                                                     item.addr, item.rdata, expected_data))
            end else begin
                match_count++;
                `uvm_info("SCB_MATCH", $sformatf("Data Match! Addr=0x%0h Data=0x%0h", 
                                                  item.addr, item.rdata), UVM_HIGH)
            end
        end

        // Check for error response
        if (item.resp == 1'b1) begin
            `uvm_warning("SCB_RESP", $sformatf("ERROR response received for Addr=0x%0h", item.addr))
        end
    endfunction

    //==========================================================================
    // Report Phase
    //==========================================================================
    function void report_phase(uvm_phase phase);
        `uvm_info("SCB_REPORT", "========================================", UVM_NONE)
        `uvm_info("SCB_REPORT", "       AHB Scoreboard Summary           ", UVM_NONE)
        `uvm_info("SCB_REPORT", "========================================", UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("Total Writes    : %0d", write_count), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("Total Reads     : %0d", read_count), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("Read Matches    : %0d", match_count), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("Read Mismatches : %0d", mismatch_count), UVM_NONE)
        `uvm_info("SCB_REPORT", "========================================", UVM_NONE)
        
        if (mismatch_count > 0) begin
            `uvm_error("SCB_FAIL", $sformatf("TEST FAILED: %0d mismatches detected!", mismatch_count))
        end else begin
            `uvm_info("SCB_PASS", "TEST PASSED: All reads matched!", UVM_NONE)
        end
    endfunction

endclass
