class apb_seq_item #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_sequence_item;

    `uvm_object_utils(apb_seq_item)

    rand bit [ADDR_WIDTH-1:0] addr;
    rand bit [DATA_WIDTH-1:0] data;
    rand bit                  write; // 1 = Write, 0 = Read
    rand int                  delay; // Delay before setup phase

    bit [DATA_WIDTH-1:0]      rdata; // Read data captured
    bit                       resp;  // Response (pslverr)

    constraint c_delay {
        delay inside {[0:10]};
    }

    constraint c_addr_align {
        addr[1:0] == 2'b00; // Word aligned
    }

    function new(string name = "apb_seq_item");
        super.new(name);
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("addr", addr, ADDR_WIDTH, UVM_HEX);
        printer.print_field("data", data, DATA_WIDTH, UVM_HEX);
        printer.print_string("kind", write ? "WRITE" : "READ");
        printer.print_field("delay", delay, 32, UVM_DEC);
    endfunction

endclass
