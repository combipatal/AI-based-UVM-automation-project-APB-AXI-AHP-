class ahb_seq_item #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_sequence_item;

    `uvm_object_param_utils(ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH))

    //==========================================================================
    // Transaction Fields
    //==========================================================================
    
    // Randomizable fields (stimulus)
    rand bit [ADDR_WIDTH-1:0] addr;
    rand bit [DATA_WIDTH-1:0] data;
    rand bit                  write;    // 1 = Write, 0 = Read
    rand bit [2:0]            size;     // HSIZE: 000=Byte, 001=Halfword, 010=Word
    rand bit [1:0]            trans;    // HTRANS: 00=IDLE, 10=NONSEQ, 11=SEQ
    rand bit [2:0]            burst;    // HBURST: 000=SINGLE
    rand int                  delay;    // Delay before transfer

    // Response fields (captured from DUT)
    bit [DATA_WIDTH-1:0]      rdata;    // Read data captured
    bit                       resp;     // HRESP (0 = OKAY, 1 = ERROR)

    //==========================================================================
    // Constraints
    //==========================================================================
    
    // Delay constraint
    constraint c_delay {
        delay inside {[0:5]};
    }

    // Transfer type constraint (AHB-Lite: mainly NONSEQ for single transfers)
    constraint c_trans {
        trans inside {2'b00, 2'b10};  // IDLE or NONSEQ
    }

    // Burst type constraint (AHB-Lite: mainly SINGLE)
    constraint c_burst {
        burst == 3'b000;  // SINGLE
    }

    // Size constraint (support Byte, Halfword, Word)
    constraint c_size {
        size inside {3'b000, 3'b001, 3'b010};
    }

    // Address alignment based on size
    constraint c_addr_align {
        (size == 3'b000) -> (1);                    // Byte: no alignment
        (size == 3'b001) -> (addr[0] == 1'b0);      // Halfword: 2-byte aligned
        (size == 3'b010) -> (addr[1:0] == 2'b00);   // Word: 4-byte aligned
    }

    //==========================================================================
    // Constructor
    //==========================================================================
    function new(string name = "ahb_seq_item");
        super.new(name);
    endfunction

    //==========================================================================
    // Utility Functions
    //==========================================================================
    
    // Convert HTRANS to string
    function string trans2str();
        case (trans)
            2'b00: return "IDLE";
            2'b01: return "BUSY";
            2'b10: return "NONSEQ";
            2'b11: return "SEQ";
        endcase
    endfunction

    // Convert HSIZE to string
    function string size2str();
        case (size)
            3'b000: return "BYTE";
            3'b001: return "HALFWORD";
            3'b010: return "WORD";
            default: return "UNKNOWN";
        endcase
    endfunction

    // Print function
    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("addr", addr, ADDR_WIDTH, UVM_HEX);
        printer.print_field("data", data, DATA_WIDTH, UVM_HEX);
        printer.print_string("kind", write ? "WRITE" : "READ");
        printer.print_string("trans", trans2str());
        printer.print_string("size", size2str());
        printer.print_field("delay", delay, 32, UVM_DEC);
        if (!write) printer.print_field("rdata", rdata, DATA_WIDTH, UVM_HEX);
        printer.print_field("resp", resp, 1, UVM_BIN);
    endfunction

    // Copy function
    virtual function void do_copy(uvm_object rhs);
        ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        addr  = rhs_.addr;
        data  = rhs_.data;
        write = rhs_.write;
        size  = rhs_.size;
        trans = rhs_.trans;
        burst = rhs_.burst;
        delay = rhs_.delay;
        rdata = rhs_.rdata;
        resp  = rhs_.resp;
    endfunction

    // Compare function
    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        ahb_seq_item#(ADDR_WIDTH, DATA_WIDTH) rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (super.do_compare(rhs, comparer) &&
                addr  == rhs_.addr  &&
                data  == rhs_.data  &&
                write == rhs_.write &&
                size  == rhs_.size);
    endfunction

endclass
