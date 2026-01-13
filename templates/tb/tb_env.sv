class tb_env extends uvm_env;
    `uvm_component_utils(tb_env)

    // Instantiate Agents
    {% for intf in interfaces %}
    {{ intf.agent_type }} {{ intf.name }};
    {{ intf.protocol }}_scoreboard#(32, 32) {{ intf.name }}_scb;
    {% endfor %}

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        {% for intf in interfaces %}
        {{ intf.name }} = {{ intf.agent_type }}::type_id::create("{{ intf.name }}", this);
        // Scoreboard
        {{ intf.name }}_scb = {{ intf.protocol }}_scoreboard#(32, 32)::type_id::create("{{ intf.name }}_scb", this);
        {% endfor %}
    endfunction

    function void connect_phase(uvm_phase phase);
        {% for intf in interfaces %}
        {{ intf.name }}.monitor.item_collected_port.connect({{ intf.name }}_scb.item_collected_export);
        {% endfor %}
    endfunction

endclass
