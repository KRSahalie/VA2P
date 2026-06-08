// =============================================================================
// tx_monitor.sv
// Monitor TX — captura transacciones emitidas por el DUT (valid & ready)
//
// El DUT es el productor del lado TX. El testbench solo observa.
// =============================================================================

class tx_monitor extends uvm_monitor;
    `uvm_component_utils(tx_monitor)
    uvm_analysis_port #(tx_transaction) ap;
    virtual aligner_if.tx_monitor_mp vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual aligner_if.tx_monitor_mp)::get(
                this, "", "tx_vif", vif))
            `uvm_fatal("TX_MON", "No se encontró tx_vif")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.clk);
        while (!vif.reset_n) @(posedge vif.clk);
        forever begin
            @(vif.tx_monitor_cb);
            if (vif.tx_monitor_cb.md_tx_valid && vif.tx_monitor_cb.md_tx_ready) begin
                tx_transaction tr = tx_transaction::type_id::create("tx_tr");
                tr.data   = vif.tx_monitor_cb.md_tx_data;
                tr.offset = vif.tx_monitor_cb.md_tx_offset;
                tr.size   = vif.tx_monitor_cb.md_tx_size;
                tr.valid  = vif.tx_monitor_cb.md_tx_valid;
                tr.err    = vif.tx_monitor_cb.md_tx_err;
                `uvm_info("TX_MON", tr.convert2string(), UVM_HIGH)
                ap.write(tr);
            end
        end
    endtask

endclass : tx_monitor


// =============================================================================
// tx_ready_driver.sv
// Componente auxiliar: mantiene md_tx_ready=1 permanentemente
//
// En este testbench el receptor TX siempre está listo. Si en el futuro se
// necesita back-pressure, este es el componente a modificar.
// =============================================================================

class tx_ready_driver extends uvm_component;
    `uvm_component_utils(tx_ready_driver)
    virtual aligner_if.tx_driver_mp vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aligner_if.tx_driver_mp)::get(
                this, "", "tx_vif", vif))
            `uvm_fatal("TX_RDY", "No se encontró tx_vif")
    endfunction

    task run_phase(uvm_phase phase);
        vif.tx_driver_cb.md_tx_ready <= 1'b1;
        forever @(vif.tx_driver_cb)
            vif.tx_driver_cb.md_tx_ready <= 1'b1;
    endtask

endclass : tx_ready_driver
