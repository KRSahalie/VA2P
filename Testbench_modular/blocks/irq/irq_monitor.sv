// =============================================================================
// irq_monitor.sv
// Monitor IRQ — detecta flancos de subida en la señal irq del DUT
//
// Cada flanco positivo genera un irq_transaction y lo publica en el
// analysis port para que el scoreboard lleve la cuenta.
// =============================================================================

class irq_monitor extends uvm_monitor;
    `uvm_component_utils(irq_monitor)
    uvm_analysis_port #(irq_transaction) ap;
    virtual aligner_if.irq_mp vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual aligner_if.irq_mp)::get(
                this, "", "irq_vif", vif))
            `uvm_fatal("IRQ_MON", "No se encontró irq_vif")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.clk);
        while (!vif.reset_n) @(posedge vif.clk);
        forever begin
            @(posedge vif.irq_cb.irq);
            begin
                irq_transaction tr = irq_transaction::type_id::create("irq_tr");
                tr.irq_detected = 1'b1;
                tr.timestamp    = $time;
                `uvm_info("IRQ_MON", tr.convert2string(), UVM_LOW)
                ap.write(tr);
            end
        end
    endtask

endclass : irq_monitor
