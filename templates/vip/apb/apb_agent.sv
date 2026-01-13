class apb_agent #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_agent;

    `uvm_component_param_utils(apb_agent#(ADDR_WIDTH, DATA_WIDTH))

    uvm_sequencer #(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH)) sequencer;
    apb_driver    #(ADDR_WIDTH, DATA_WIDTH)                 driver;
    apb_monitor   #(ADDR_WIDTH, DATA_WIDTH)                 monitor;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = apb_monitor#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("monitor", this);

        if(get_is_active() == UVM_ACTIVE) begin
            sequencer = uvm_sequencer#(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH))::type_id::create("sequencer", this);
            driver = apb_driver#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if(get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
