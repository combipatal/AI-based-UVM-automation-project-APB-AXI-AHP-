class ahb_agent #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_agent;

    `uvm_component_param_utils(ahb_agent#(ADDR_WIDTH, DATA_WIDTH))

    //==========================================================================
    // Components
    //==========================================================================
    uvm_sequencer #(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH)) sequencer;
    ahb_driver    #(ADDR_WIDTH, DATA_WIDTH)                driver;
    ahb_monitor   #(ADDR_WIDTH, DATA_WIDTH)                monitor;

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
        
        // Monitor is always created (passive or active)
        monitor = ahb_monitor#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("monitor", this);

        // Sequencer and Driver only for active agent
        if(get_is_active() == UVM_ACTIVE) begin
            sequencer = uvm_sequencer#(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH))::type_id::create("sequencer", this);
            driver = ahb_driver#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("driver", this);
        end
    endfunction

    //==========================================================================
    // Connect Phase
    //==========================================================================
    function void connect_phase(uvm_phase phase);
        if(get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
