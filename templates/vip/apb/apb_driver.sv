class apb_driver #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_driver #(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_component_param_utils(apb_driver#(ADDR_WIDTH, DATA_WIDTH))

    virtual apb_if#(ADDR_WIDTH, DATA_WIDTH) vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual apb_if#(ADDR_WIDTH, DATA_WIDTH))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"});
        end
    endfunction

    task run_phase(uvm_phase phase);
        // Reset initialization
        vif.psel    <= 0;
        vif.penable <= 0;
        vif.pwrite  <= 0;
        vif.paddr   <= 0;
        vif.pwdata  <= 0;

        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transfer(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH) req);
        // User defined delay
        repeat(req.delay) @(posedge vif.{{ clock_name }});

        // SETUP Phase
        @(posedge vif.{{ clock_name }});
        vif.paddr   = req.addr;    // Blocking assignment for immediate update
        vif.pwrite  = req.write;
        vif.psel    = 1;
        if(req.write) vif.pwdata = req.data;
        
        $display("[DRV_SETUP] Time=%0t Addr=0x%h Write=%b Data=0x%h psel=%b penable=%b", 
                 $time, vif.paddr, vif.pwrite, vif.pwdata, vif.psel, vif.penable);

        // ACCESS Phase
        @(posedge vif.{{ clock_name }});
        vif.penable = 1;
        
        $display("[DRV_ACCESS] Time=%0t Addr=0x%h Write=%b psel=%b penable=%b pready=%b", 
                 $time, vif.paddr, vif.pwrite, vif.psel, vif.penable, vif.pready);

        // Wait for Ready
        do begin
            @(posedge vif.{{ clock_name }});
        end while(vif.pready === 0);

        // Capture Read Data
        if(!req.write) begin
            req.rdata = vif.prdata;
            $display("[DRV_READ_CAPTURE] Time=%0t Addr=0x%h Data=0x%h", $time, vif.paddr, vif.prdata);
        end
        req.resp = vif.pslverr;

        // Idle Phase
        vif.psel    = 0;
        vif.penable = 0;
        vif.pwdata  = 0;
        
    endtask

endclass
