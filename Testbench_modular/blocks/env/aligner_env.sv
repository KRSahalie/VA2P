// =============================================================================
// aligner_env.sv
// Environment top-level del testbench cfs_aligner
//
// Instancia y conecta:
//   · rx_agt    — agente RX activo (driver + monitor + sequencer)
//   · apb_agt   — agente APB activo (driver + monitor + sequencer)
//   · tx_mon    — monitor TX pasivo
//   · irq_mon   — monitor IRQ pasivo
//   · sb        — scoreboard
//   · reg_model — modelo RAL (inyectado vía config_db desde el test)
//
// Flujo RAL:
//   test → reg_model.write/read → apb_adapter → apb_agt.sequencer → apb_driver → DUT
// =============================================================================

class aligner_env extends uvm_env;
    `uvm_component_utils(aligner_env)

    rx_agent    rx_agt;
    apb_agent   apb_agt;
    tx_monitor  tx_mon;
    irq_monitor irq_mon;
    scoreboard  sb;
    cfs_aligner_regs reg_model;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        rx_agt  = rx_agent::type_id::create("rx_agt",    this);
        apb_agt = apb_agent::type_id::create("apb_agt",  this);
        tx_mon  = tx_monitor::type_id::create("tx_mon",  this);
        irq_mon = irq_monitor::type_id::create("irq_mon", this);
        sb      = scoreboard::type_id::create("sb",      this);
        if (!uvm_config_db #(cfs_aligner_regs)::get(this, "", "reg_model", reg_model))
            `uvm_fatal("ENV", "No se encontró reg_model en env")
    endfunction

    function void connect_phase(uvm_phase phase);
        apb_adapter adapter;
        // Analysis ports → scoreboard
        rx_agt.ap.connect(sb.rx_export);
        tx_mon.ap.connect(sb.tx_export);
        irq_mon.ap.connect(sb.irq_export);
        // RAL → APB sequencer vía adapter
        adapter = apb_adapter::type_id::create("adapter");
        reg_model.default_map.set_sequencer(apb_agt.sequencer, adapter);
        reg_model.default_map.set_auto_predict(0);
    endfunction

endclass : aligner_env
