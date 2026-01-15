class ahb_driver #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_driver #(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_component_param_utils(ahb_driver#(ADDR_WIDTH, DATA_WIDTH))

    virtual ahb_if#(ADDR_WIDTH, DATA_WIDTH) vif;

    //==========================================================================
    // Constructor
    //==========================================================================
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //==========================================================================
    // Build Phase
    //==========================================================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual ahb_if#(ADDR_WIDTH, DATA_WIDTH))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"});
        end
    endfunction

    //==========================================================================
    // Run Phase
    //==========================================================================
    task run_phase(uvm_phase phase);
        // Reset initialization
        reset_signals();
        
        // Wait for reset release
        @(posedge vif.hresetn);
        
        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    //==========================================================================
    // Reset Signals
    //==========================================================================
    task reset_signals();
        vif.haddr   <= '0;
        vif.htrans  <= 2'b00;  // IDLE
        vif.hwrite  <= 1'b0;
        vif.hsize   <= 3'b010; // Word
        vif.hburst  <= 3'b000; // SINGLE
        vif.hprot   <= 4'b0000;
        vif.hsel    <= 1'b0;
        vif.hwdata  <= '0;
    endtask

    //==========================================================================
    // Drive Transfer (AHB-Lite Protocol)
    //==========================================================================
    virtual task drive_transfer(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) req);
        
        // User defined delay
        repeat(req.delay) @(posedge vif.hclk);

        //======================================================================
        // ADDRESS PHASE
        //======================================================================
        @(posedge vif.hclk);
        
        // Drive address phase signals
        vif.haddr   <= req.addr;
        vif.htrans  <= req.trans;  // NONSEQ for single transfer
        vif.hwrite  <= req.write;
        vif.hsize   <= req.size;
        vif.hburst  <= req.burst;  // SINGLE
        vif.hsel    <= 1'b1;
        
        // For write, prepare data (will be sampled in data phase)
        if (req.write) begin
            vif.hwdata <= req.data;
        end

        $display("[AHB_DRV_ADDR] Time=%0t Addr=0x%h Write=%b Size=%0d Trans=%0d", 
                 $time, req.addr, req.write, req.size, req.trans);

        //======================================================================
        // DATA PHASE
        //======================================================================
        // Wait for HREADY (slave ready)
        do begin
            @(posedge vif.hclk);
        end while (vif.hready !== 1'b1);

        // For write: HWDATA is sampled here
        // For read: Capture HRDATA
        if (!req.write) begin
            req.rdata = vif.hrdata;
            $display("[AHB_DRV_READ] Time=%0t Addr=0x%h Data=0x%h", 
                     $time, req.addr, vif.hrdata);
        end else begin
            $display("[AHB_DRV_WRITE] Time=%0t Addr=0x%h Data=0x%h", 
                     $time, req.addr, req.data);
        end
        
        // Capture response
        req.resp = vif.hresp;

        //======================================================================
        // IDLE (End of Transfer)
        //======================================================================
        // Return to IDLE state
        vif.htrans <= 2'b00;  // IDLE
        vif.hsel   <= 1'b0;

    endtask

endclass
