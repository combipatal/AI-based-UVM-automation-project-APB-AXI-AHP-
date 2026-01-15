class ahb_base_seq #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_sequence #(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_object_param_utils(ahb_base_seq#(ADDR_WIDTH, DATA_WIDTH))

    //==========================================================================
    // Constructor
    //==========================================================================
    function new(string name = "ahb_base_seq");
        super.new(name);
    endfunction

    //==========================================================================
    // Body Task
    //==========================================================================
    task body();
        bit [ADDR_WIDTH-1:0] addr;
        bit [DATA_WIDTH-1:0] data;
        
        // Test Plan Configuration (from config.yaml via Jinja2)
        {% if test_plan %}
        localparam int ITERATIONS = {{ test_plan.constraints.iterations | default(20) }};
        localparam int ADDR_MIN   = {{ test_plan.constraints.addr.min | default(0) }};
        localparam int ADDR_MAX   = {{ test_plan.constraints.addr.max | default(4095) }};
        localparam int ADDR_ALIGN = {{ test_plan.constraints.addr.align | default(4) }};
        {% else %}
        localparam int ITERATIONS = 20;
        localparam int ADDR_MIN   = 0;
        localparam int ADDR_MAX   = 4095;  // 4KB memory
        localparam int ADDR_ALIGN = 4;
        {% endif %}
        
        `uvm_info(get_type_name(), $sformatf("Starting %0d iterations of AHB Write-Read Test...", ITERATIONS), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("Addr Range: 0x%0h ~ 0x%0h, Align: %0d", ADDR_MIN, ADDR_MAX, ADDR_ALIGN), UVM_LOW)
        
        repeat(ITERATIONS) begin
            // Randomize address and data with constraints
            if (!std::randomize(addr, data) with { 
                addr >= ADDR_MIN;
                addr <= ADDR_MAX;
                addr % ADDR_ALIGN == 0;  // Word alignment
            }) `uvm_error("RND", "Randomization failed")
            
            // Execute Write followed by Read (Scoreboard verifies)
            sanity_check(addr, data);
        end
        
        `uvm_info(get_type_name(), "AHB Sequence complete", UVM_LOW)
    endtask

    //==========================================================================
    // Sanity Check: Write then Read
    //==========================================================================
    task sanity_check(input bit [ADDR_WIDTH-1:0] addr, input bit [DATA_WIDTH-1:0] data);
        ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) req;
        
        //======================================================================
        // WRITE Transaction
        //======================================================================
        req = ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
        start_item(req);
        if(!req.randomize() with { 
            addr  == local::addr; 
            write == 1; 
            data  == local::data;
            trans == 2'b10;  // NONSEQ
            size  == 3'b010; // WORD
        }) `uvm_fatal("RNDFAIL", "Write randomization failed")
        finish_item(req);
        
        //======================================================================
        // READ Transaction
        //======================================================================
        req = ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
        start_item(req);
        if(!req.randomize() with { 
            addr  == local::addr; 
            write == 0;
            trans == 2'b10;  // NONSEQ
            size  == 3'b010; // WORD
        }) `uvm_fatal("RNDFAIL", "Read randomization failed")
        finish_item(req);
    endtask

    //==========================================================================
    // Helper Tasks for Custom Sequences
    //==========================================================================
    
    // Single Write
    task ahb_write(input bit [ADDR_WIDTH-1:0] addr, 
                   input bit [DATA_WIDTH-1:0] data,
                   input bit [2:0] size = 3'b010);  // Default: WORD
        ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) req;
        req = ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
        start_item(req);
        if(!req.randomize() with {
            addr  == local::addr;
            data  == local::data;
            write == 1;
            size  == local::size;
            trans == 2'b10;  // NONSEQ
        }) `uvm_fatal("RNDFAIL", "ahb_write randomization failed")
        finish_item(req);
    endtask

    // Single Read
    task ahb_read(input bit [ADDR_WIDTH-1:0] addr,
                  output bit [DATA_WIDTH-1:0] rdata,
                  input bit [2:0] size = 3'b010);  // Default: WORD
        ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) req;
        req = ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
        start_item(req);
        if(!req.randomize() with {
            addr  == local::addr;
            write == 0;
            size  == local::size;
            trans == 2'b10;  // NONSEQ
        }) `uvm_fatal("RNDFAIL", "ahb_read randomization failed")
        finish_item(req);
        rdata = req.rdata;
    endtask

endclass
