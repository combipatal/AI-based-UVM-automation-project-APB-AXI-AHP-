class apb_monitor #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_monitor;

    `uvm_component_param_utils(apb_monitor#(ADDR_WIDTH, DATA_WIDTH))

    virtual apb_if#(ADDR_WIDTH, DATA_WIDTH) vif;
    uvm_analysis_port #(apb_seq_item#(ADDR_WIDTH, DATA_WIDTH)) item_collected_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual apb_if#(ADDR_WIDTH, DATA_WIDTH))::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(), ".vif"});
        end
    endfunction

    task run_phase(uvm_phase phase);
        // 리셋 대기 후 시작
        wait(vif.{{ reset_name }} === 1);
        forever begin
            collect_transfer();
        end
    endtask

    virtual task collect_transfer();
        apb_seq_item#(ADDR_WIDTH, DATA_WIDTH) tr;
        
        // 1. SETUP 단계 감지 (PSEL=1, PENABLE=0)
        // CRITICAL: 조건을 먼저 체크하고, 만족하지 않으면 clock 대기
        // #0 delay로 같은 clock edge의 신호 변화를 캡처
        #0;
        while (vif.psel !== 1 || vif.penable !== 0) begin
            @(posedge vif.{{ clock_name }});
            #0; // Allow blocking assignments to settle
            if (vif.{{ reset_name }} === 0) return; 
        end

        // SETUP 단계 발견! -> 트랜잭션 객체 생성 및 주소/컨트롤 샘플링
        tr = apb_seq_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("tr");
        tr.addr  = vif.paddr;
        tr.write = vif.pwrite;
        if (tr.write) tr.data = vif.pwdata;

        $display("[MON_SETUP] Time=%0t Addr=0x%h Write=%b", $time, tr.addr, tr.write);

        // 2. ACCESS 단계 및 완료 대기 (PREADY=1)
        // APB 스펙상 SETUP 다음 사이클에 PENABLE이 1이 됩니다.
        // PREADY가 1이 될 때까지 대기합니다.
        @(posedge vif.{{ clock_name }}); 
        while (vif.pready !== 1) begin
            @(posedge vif.{{ clock_name }});
             if (vif.{{ reset_name }} === 0) return; // 리셋 보호
        end

        // 3. 완료 시점 (Access Phase + Ready=1) 데이터 샘플링
        // 이때 Read Data와 Response가 유효합니다.
        if (!tr.write) begin
            tr.rdata = vif.prdata;
            tr.data  = vif.prdata; // 편의상 data 필드에도 복사 (구현에 따라 다름)
            $display("[MON_READ_DONE] Time=%0t Addr=0x%h RData=0x%h", $time, tr.addr, tr.rdata);
        end else begin
            $display("[MON_WRITE_DONE] Time=%0t Addr=0x%h WData=0x%h", $time, tr.addr, tr.data);
        end
        tr.resp = vif.pslverr;

        // 4. Analysis Port 전송
        item_collected_port.write(tr);

    endtask

endclass