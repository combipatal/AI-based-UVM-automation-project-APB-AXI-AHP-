
class axi_agent #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_agent;
    `uvm_component_param_utils(axi_agent#(ADDR_WIDTH, DATA_WIDTH))

    uvm_sequencer #(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)) sequencer;
    axi_driver    #(ADDR_WIDTH, DATA_WIDTH) driver;
    axi_monitor   #(ADDR_WIDTH, DATA_WIDTH) monitor;

    virtual axi_if#(ADDR_WIDTH, DATA_WIDTH) vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = axi_monitor#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("monitor", this);

        if(get_is_active() == UVM_ACTIVE) begin
            sequencer = uvm_sequencer#(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH))::type_id::create("sequencer", this);
            driver = axi_driver#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("driver", this);
        end

        if(!uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH))::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"});
        
        uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH))::set(this, "monitor", "vif", vif);
        uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH))::set(this, "driver", "vif", vif);
    endfunction

    function void connect_phase(uvm_phase phase);
        if(get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
