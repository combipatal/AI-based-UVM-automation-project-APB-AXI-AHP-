class apb_test extends uvm_test;
    `uvm_component_utils(apb_test)

    tb_env env;

    function new(string name = "apb_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = tb_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        apb_base_seq#({{ addr_width }}, {{ data_width }}) seq;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "Starting APB Test Sequence...", UVM_LOW)
        
        seq = apb_base_seq#({{ addr_width }}, {{ data_width }})::type_id::create("seq");
        
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
