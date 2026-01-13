class apb_base_seq #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_sequence #(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_object_param_utils(apb_base_seq#(ADDR_WIDTH, DATA_WIDTH))

    function new(string name = "apb_base_seq");
        super.new(name);
    endfunction

    task body();
        bit [ADDR_WIDTH-1:0] addr;
        bit [DATA_WIDTH-1:0] data;
        
        // Test Plan Configuration (from config.yaml)
        {% if test_plan %}
        localparam int ITERATIONS = {{ test_plan.constraints.iterations | default(20) }};
        localparam int ADDR_MIN   = {{ test_plan.constraints.addr.min | default(0) }};
        localparam int ADDR_MAX   = {{ test_plan.constraints.addr.max | default(1023) }};
        localparam int ADDR_ALIGN = {{ test_plan.constraints.addr.align | default(4) }};
        {% else %}
        localparam int ITERATIONS = 20;
        localparam int ADDR_MIN   = 0;
        localparam int ADDR_MAX   = 1023;
        localparam int ADDR_ALIGN = 4;
        {% endif %}
        
        `uvm_info(get_type_name(), $sformatf("Starting %0d iterations of Write-Read Test...", ITERATIONS), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Addr Range: 0x%0h ~ 0x%0h, Align: %0d", ADDR_MIN, ADDR_MAX, ADDR_ALIGN), UVM_LOW)
        
        repeat(ITERATIONS) begin
            // Randomize address and data with constraints from test_plan
            if (!std::randomize(addr, data) with { 
                addr >= ADDR_MIN;
                addr <= ADDR_MAX;
                addr % ADDR_ALIGN == 0;  // Alignment constraint
            }) `uvm_error("RND", "Randomization failed")
            
            // Execute Write followed by Read (checks Scoreboard)
            sanity_check(addr, data);
        end
        
        `uvm_info(get_type_name(), "Sequence complete", UVM_LOW)
    endtask

    // Helper task for sanity check (Write then Read)
    task sanity_check(input bit [ADDR_WIDTH-1:0] addr, input bit [DATA_WIDTH-1:0] data);
        apb_seq_item#(ADDR_WIDTH, DATA_WIDTH) req;
        
        // Write
        req = apb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
        start_item(req);
        if(!req.randomize() with { 
            addr == local::addr; 
            write == 1; 
            data == local::data; 
        }) `uvm_fatal("RNDFAIL", "Randomization failed")
        finish_item(req);
        
        // Read
        req = apb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
        start_item(req);
        if(!req.randomize() with { 
            addr == local::addr; 
            write == 0; 
        }) `uvm_fatal("RNDFAIL", "Randomization failed")
        finish_item(req);
    endtask

endclass

