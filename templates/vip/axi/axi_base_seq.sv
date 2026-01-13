
class axi_base_seq #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_sequence #(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH));

    `uvm_object_param_utils(axi_base_seq#(ADDR_WIDTH, DATA_WIDTH))

    function new(string name = "axi_base_seq");
        super.new(name);
    endfunction
    // Wait, uvm_sequence new only takes name.
    
    // Test Plan Configuration (from config.yaml)
    {% if test_plan %}
    localparam int ITERATIONS = {{ test_plan.constraints.iterations }};
    localparam int ADDR_MIN   = {{ test_plan.constraints.addr.min }};
    localparam int ADDR_MAX   = {{ test_plan.constraints.addr.max }};
    localparam int ADDR_ALIGN = {{ test_plan.constraints.addr.align }};
    {% else %}
    localparam int ITERATIONS = 20;
    localparam int ADDR_MIN   = 0;
    localparam int ADDR_MAX   = 1020;
    localparam int ADDR_ALIGN = 4;
    {% endif %}

    task body();
        bit [ADDR_WIDTH-1:0] addr;
        bit [DATA_WIDTH-1:0] data;
        
        `uvm_info(get_type_name(), $sformatf("Starting %0d iterations of AXI Write-Read Test...", ITERATIONS), UVM_LOW)

        repeat(ITERATIONS) begin
             if (!std::randomize(addr, data) with { 
                addr >= ADDR_MIN;
                addr <= ADDR_MAX;
                addr % ADDR_ALIGN == 0;
            }) `uvm_error("RND", "Randomization failed")

            // Write
            `uvm_do_with(req, {
                kind == axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::WRITE;
                addr == local::addr;
                data == local::data;
                strb == {(DATA_WIDTH/8){1'b1}};
            })
            
            // Read
            `uvm_do_with(req, {
                kind == axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::READ;
                addr == local::addr;
            })
        end

        `uvm_info(get_type_name(), "Sequence complete", UVM_LOW)
    endtask

endclass
