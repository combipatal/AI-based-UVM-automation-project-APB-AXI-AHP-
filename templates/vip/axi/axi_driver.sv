
class axi_driver #(
    int ADDR_WIDTH = {{ ADDR_WIDTH }},
    int DATA_WIDTH = {{ DATA_WIDTH }}
) extends uvm_driver #(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH));
    `uvm_component_param_utils(axi_driver#(ADDR_WIDTH, DATA_WIDTH))

    virtual axi_if#(ADDR_WIDTH, DATA_WIDTH) vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual axi_if#(ADDR_WIDTH, DATA_WIDTH))::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"});
    endfunction

    task run_phase(uvm_phase phase);
        // Reset Phase
        vif.awvalid <= 0;
        vif.wvalid  <= 0;
        vif.bready  <= 0;
        vif.arvalid <= 0;
        vif.rready  <= 0;
        vif.wstrb   <= {(DATA_WIDTH/8){1'b1}};

        wait(vif.aresetn == 1);
        @(posedge vif.aclk);

        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_transfer(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH) item);
        if (item.kind == axi_seq_item#(ADDR_WIDTH, DATA_WIDTH)::WRITE) begin
            drive_write(item);
        end else begin
            drive_read(item);
        end
    endtask

    task drive_write(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH) item);
        `uvm_info("DRV", $sformatf("WRITE Start: Addr=0x%0h Data=0x%0h", item.addr, item.data), UVM_HIGH)

        // 1. Write Address Channel
        vif.awaddr  <= item.addr;
        vif.awvalid <= 1;
        
        // 2. Write Data Channel
        vif.wdata   <= item.data;
        vif.wstrb   <= item.strb;
        vif.wvalid  <= 1;

        // 3. Response Ready
        vif.bready  <= 1;

        // Wait for Handshakes
        fork
            begin
                wait_aw_handshake();
            end
            begin
                wait_w_handshake();
            end
        join

        // Wait for Response
        wait_b_handshake();
        vif.bready <= 0;

        `uvm_info("DRV", "WRITE Done", UVM_HIGH)
    endtask

    task wait_aw_handshake();
        do begin
            @(posedge vif.aclk);
        end while (!(vif.awvalid && vif.awready));
        vif.awvalid <= 0;
    endtask

    task wait_w_handshake();
        do begin
            @(posedge vif.aclk);
        end while (!(vif.wvalid && vif.wready));
        vif.wvalid <= 0;
    endtask

    task wait_b_handshake();
        do begin
            @(posedge vif.aclk);
        end while (!(vif.bvalid && vif.bready));
    endtask

    task drive_read(axi_seq_item#(ADDR_WIDTH, DATA_WIDTH) item);
        `uvm_info("DRV", $sformatf("READ Start: Addr=0x%0h", item.addr), UVM_HIGH)

        // 1. Read Address Channel
        vif.araddr  <= item.addr;
        vif.arvalid <= 1;
        vif.rready  <= 1; // Always ready to receive data

        // Wait for AR Handshake
        do begin
            @(posedge vif.aclk);
        end while (!(vif.arvalid && vif.arready));
        vif.arvalid <= 0;

        // Wait for Read Data (R Handshake)
        do begin
            @(posedge vif.aclk);
        end while (!(vif.rvalid && vif.rready));

        item.data = vif.rdata;
        vif.rready <= 0;

        `uvm_info("DRV", $sformatf("READ Done: Data=0x%0h", item.data), UVM_HIGH)
    endtask

endclass
