// =============================================================================
// apb_monitor.sv
// Monitor APB —
//
// Captura transacciones APB completadas (psel & penable & pready) y las
// publica en el analysis port para el scoreboard y el predictor RAL.
//
// Nota: usa virtual aligner_if sin modport (necesario por limitaciones del
// UVM config_db con interfaces que tienen múltiples clocking blocks).
// =============================================================================

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    uvm_analysis_port #(apb_transaction) ap;
    virtual aligner_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual aligner_if)::get(
                this, "", "apb_vif", vif))
            `uvm_fatal("APB_MON", "No se encontró apb_vif")
    endfunction

    task run_phase(uvm_phase phase);
        apb_transaction tr;
        @(posedge vif.clk);
        while (!vif.reset_n) @(posedge vif.clk);
        forever begin
            @(posedge vif.clk); #1step;
            if (vif.psel && vif.penable && vif.pready) begin
                tr        = apb_transaction::type_id::create("tr");
                tr.addr   = vif.paddr;
                tr.write  = vif.pwrite;
                tr.data   = vif.pwrite ? vif.pwdata : vif.prdata;
                tr.slverr = vif.pslverr;
                ap.write(tr);
            end
        end
    endtask

endclass : apb_monitor


// =============================================================================
// apb_agent.sv
// Agente APB: agrupa sequencer + driver + monitor
// — NO TOCAR
// =============================================================================

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    uvm_sequencer #(apb_transaction) sequencer;
    apb_driver  driver;
    apb_monitor monitor;
    uvm_analysis_port #(apb_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap        = new("ap", this);
        sequencer = uvm_sequencer #(apb_transaction)::type_id::create("sequencer", this);
        driver    = apb_driver::type_id::create("driver", this);
        monitor   = apb_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
        monitor.ap.connect(ap);
    endfunction

endclass : apb_agent
