
class axi_seq_item #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_sequence_item;

    // Transaction Type
    typedef enum bit {READ, WRITE} kind_e;
    rand kind_e kind;

    // Address and Data
    rand bit [ADDR_WIDTH-1:0] addr;
    rand bit [DATA_WIDTH-1:0] data;
    rand bit [(DATA_WIDTH/8)-1:0] strb;

    // Response
    bit [1:0] resp; // 00: OKAY, 01: EXOKAY, 10: SLVERR, 11: DECERR

    `uvm_object_param_utils_begin(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH))
        `uvm_field_enum(kind_e, kind, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(data, UVM_ALL_ON)
        `uvm_field_int(strb, UVM_ALL_ON)
        `uvm_field_int(resp, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_seq_item");
        super.new(name);
        strb = {(DATA_WIDTH/8){1'b1}}; // Default full write
    endfunction

endclass
