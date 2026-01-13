
class axi_test extends uvm_test;
    `uvm_component_utils(axi_test)

    tb_env env;

    function new(string name = "axi_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = tb_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        axi_base_seq#({{ addr_width }}, {{ data_width }}) seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting AXI Test Sequence...", UVM_LOW)
        
        seq = axi_base_seq#({{ addr_width }}, {{ data_width }})::type_id::create("seq");
        
        // Start sequence on the sequencer of the first interface
        // Access via Env -> Agent -> Sequencer
        // We assume the first interface in the list is the target.
        if (env.{{ interfaces[0].name }}.sequencer != null)
             seq.start(env.{{ interfaces[0].name }}.sequencer);
        else
             `uvm_fatal("NOSEQ", "Sequencer not found")
        
        phase.drop_objection(this);
    endtask

endclass
