package tb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import VIP Packages
    {% for pkg in vip_packages %}
    import {{ pkg }}::*;
    {% endfor %}

    // Include Environment
    `include "tb_env.sv"

    // Include Tests
    `include "{{ test_name }}.sv" 

endpackage
