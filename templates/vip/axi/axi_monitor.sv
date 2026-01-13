
class axi_monitor #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_monitor;
    `uvm_component_param_utils(axi_monitor#(ADDR_WIDTH, DATA_WIDTH))

    virtual axi_if#(ADDR_WIDTH, DATA_WIDTH) vif;
    uvm_analysis_port #(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH))::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"});
    endfunction

    task run_phase(uvm_phase phase);
        // Fork separate monitors for Read and Write channels since they can overlap
        fork
            monitor_write();
            monitor_read();
        join
    endtask

    task monitor_write();
        axi_seq_item#(ADDR_WIDTH, DATA_WIDTH) item;
        bit [ADDR_WIDTH-1:0] captured_addr;
        bit [DATA_WIDTH-1:0] captured_data;

        forever begin
            item = axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("item");
            item.kind = axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::WRITE;

            // Wait for Write Address Handshake
            wait(vif.awvalid && vif.awready);
            captured_addr = vif.awaddr;
            @(posedge vif.aclk);

            // Capture Write Data
            if (!(vif.wvalid && vif.wready)) begin
                wait(vif.wvalid && vif.wready);
            end
            captured_data = vif.wdata;
            @(posedge vif.aclk);

            // Wait for Response
            if (!(vif.bvalid && vif.bready)) begin
                wait(vif.bvalid && vif.bready);
            end
            @(posedge vif.aclk);

            // Publish Item
            item.addr = captured_addr;
            item.data = captured_data;
            item_collected_port.write(item);
            $display("[MON] WRITE: Addr=0x%0h Data=0x%0h", item.addr, item.data);
        end
    endtask

    task monitor_read();
        axi_seq_item#(ADDR_WIDTH, DATA_WIDTH) item;
        
        forever begin
            item = axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("item");
            item.kind = axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::READ;

            // Wait for AR Handshake
            wait(vif.arvalid && vif.arready);
            item.addr = vif.araddr;
            @(posedge vif.aclk);

            // Wait for R Handshake
            if (!(vif.rvalid && vif.rready)) begin
                wait(vif.rvalid && vif.rready);
            end
            item.data = vif.rdata;
            @(posedge vif.aclk);

            // Publish Item
            item_collected_port.write(item);
            $display("[MON] READ: Addr=0x%0h Data=0x%0h", item.addr, item.data);
        end
    endtask

endclass
