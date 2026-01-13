
// DPI Imports
import "DPI-C" context function void dpi_mem_write(int addr, int data);
import "DPI-C" context function int  dpi_mem_read(int addr);

class axi_scoreboard #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_scoreboard;
    `uvm_component_param_utils(axi_scoreboard#(ADDR_WIDTH, DATA_WIDTH))

    uvm_analysis_imp #(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH), axi_scoreboard#(ADDR_WIDTH, DATA_WIDTH)) item_collected_export;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
    endfunction

    function void write(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH) item);
        int expected_data;

        if (item.kind == axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::WRITE) begin
            `uvm_info("SCB", $sformatf("WRITE: Addr=0x%0h Data=0x%0h", item.addr, item.data), UVM_MEDIUM)
            
            // Update Python Model
            dpi_mem_write(item.addr, item.data);
            
        end else begin
            // Read from Python Model (Expected)
            expected_data = dpi_mem_read(item.addr);
            
            `uvm_info("SCB", $sformatf("READ: Addr=0x%0h | DUT=0x%0h vs Model=0x%0h", item.addr, item.data, expected_data), UVM_MEDIUM)

            if (item.data !== expected_data) begin
                `uvm_error("SCB_MISMATCH", $sformatf("Data Mismatch! Addr=0x%0h DUT=0x%0h Exp=0x%0h", item.addr, item.data, expected_data))
            end else begin
                `uvm_info("SCB_MATCH", "Read Data Match!", UVM_MEDIUM)
            end
        end
    endfunction

endclass
