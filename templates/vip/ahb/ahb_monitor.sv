class ahb_monitor #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_monitor;

    `uvm_component_param_utils(ahb_monitor#(ADDR_WIDTH, DATA_WIDTH))

    virtual ahb_if#(ADDR_WIDTH, DATA_WIDTH) vif;
    uvm_analysis_port #(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH)) item_collected_port;

    //==========================================================================
    // Constructor
    //==========================================================================
    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
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
        // Wait for reset release
        wait(vif.hresetn === 1);
        
        forever begin
            collect_transfer();
        end
    endtask

    //==========================================================================
    // Collect Transfer (AHB-Lite Protocol)
    //==========================================================================
    virtual task collect_transfer();
        ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) tr;
        
        // Storage for address phase info
        bit [ADDR_WIDTH-1:0] addr_phase_addr;
        bit                  addr_phase_write;
        bit [2:0]            addr_phase_size;
        bit [1:0]            addr_phase_trans;
        bit [DATA_WIDTH-1:0] addr_phase_wdata;

        //======================================================================
        // 1. Wait for valid Address Phase
        //    Condition: HSEL=1 and HTRANS=NONSEQ or SEQ
        //======================================================================
        #0;  // Allow signals to settle
        while (!(vif.hsel === 1'b1 && (vif.htrans === 2'b10 || vif.htrans === 2'b11))) begin
            @(posedge vif.hclk);
            #0;
            if (vif.hresetn === 0) return;  // Reset protection
        end

        // Capture Address Phase signals
        addr_phase_addr  = vif.haddr;
        addr_phase_write = vif.hwrite;
        addr_phase_size  = vif.hsize;
        addr_phase_trans = vif.htrans;
        if (addr_phase_write) begin
            addr_phase_wdata = vif.hwdata;
        end

        $display("[AHB_MON_ADDR] Time=%0t Addr=0x%h Write=%b Size=%0d Trans=%0d", 
                 $time, addr_phase_addr, addr_phase_write, addr_phase_size, addr_phase_trans);

        //======================================================================
        // 2. Wait for Data Phase completion (HREADY = 1)
        //======================================================================
        @(posedge vif.hclk);
        while (vif.hready !== 1'b1) begin
            @(posedge vif.hclk);
            if (vif.hresetn === 0) return;  // Reset protection
        end

        //======================================================================
        // 3. Create transaction and capture data
        //======================================================================
        tr = ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("tr");
        
        tr.addr  = addr_phase_addr;
        tr.write = addr_phase_write;
        tr.size  = addr_phase_size;
        tr.trans = addr_phase_trans;
        tr.resp  = vif.hresp;

        if (tr.write) begin
            // Write: capture write data (was driven in address phase for AHB-Lite)
            tr.data = addr_phase_wdata;
            $display("[AHB_MON_WRITE] Time=%0t Addr=0x%h Data=0x%h Resp=%b", 
                     $time, tr.addr, tr.data, tr.resp);
        end else begin
            // Read: capture read data from HRDATA
            tr.rdata = vif.hrdata;
            tr.data  = vif.hrdata;  // Copy to data field for convenience
            $display("[AHB_MON_READ] Time=%0t Addr=0x%h Data=0x%h Resp=%b", 
                     $time, tr.addr, tr.rdata, tr.resp);
        end

        //======================================================================
        // 4. Send to Analysis Port
        //======================================================================
        item_collected_port.write(tr);

    endtask

endclass
