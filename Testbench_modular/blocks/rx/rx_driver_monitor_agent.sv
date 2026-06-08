// =============================================================================
// rx_driver.sv
// Driver RX — maneja handshake valid/ready sobre rx_driver_cb
//
// Protocolo:
//   · Transacción válida: assert valid, espera ready, luego idle 1 ciclo
//   · Transacción inválida (valid=0): idle 2 ciclos (gap)
// =============================================================================

class rx_driver extends uvm_driver #(rx_transaction);
    `uvm_component_utils(rx_driver)
    virtual aligner_if.rx_driver_mp vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aligner_if.rx_driver_mp)::get(
                this, "", "rx_vif", vif))
            `uvm_fatal("RX_DRV", "No se encontró rx_vif")
    endfunction

    task run_phase(uvm_phase phase);
        drive_idle();
        @(posedge vif.clk);
        while (!vif.reset_n) @(posedge vif.clk);
        `uvm_info("RX_DRV", "Reset liberado", UVM_LOW)
        forever begin
            rx_transaction tr;
            seq_item_port.get_next_item(tr);
            if (!tr.valid) begin
                drive_idle();
                repeat(2) @(vif.rx_driver_cb);
            end else begin
                drive_transaction(tr);
            end
            `uvm_info("RX_DRV", tr.convert2string(), UVM_MEDIUM)
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(rx_transaction tr);
        vif.rx_driver_cb.md_rx_valid  <= 1'b1;
        vif.rx_driver_cb.md_rx_data   <= tr.data;
        vif.rx_driver_cb.md_rx_offset <= tr.offset;
        vif.rx_driver_cb.md_rx_size   <= tr.size;
        @(vif.rx_driver_cb);
        while (!vif.rx_driver_cb.md_rx_ready) @(vif.rx_driver_cb);
        drive_idle();
        @(vif.rx_driver_cb);
    endtask

    task drive_idle();
        vif.rx_driver_cb.md_rx_valid  <= 1'b0;
        vif.rx_driver_cb.md_rx_data   <= 32'h0;
        vif.rx_driver_cb.md_rx_offset <= 2'b00;
        vif.rx_driver_cb.md_rx_size   <= 3'd1;
    endtask

endclass : rx_driver


// =============================================================================
// rx_monitor.sv
// Monitor RX — captura transacciones aceptadas (valid & ready simultáneos)
// =============================================================================

class rx_monitor extends uvm_monitor;
    `uvm_component_utils(rx_monitor)
    uvm_analysis_port #(rx_transaction) ap;
    virtual aligner_if.rx_monitor_mp vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual aligner_if.rx_monitor_mp)::get(
                this, "", "rx_vif", vif))
            `uvm_fatal("RX_MON", "No se encontró rx_vif")
    endfunction

    task run_phase(uvm_phase phase);
        @(posedge vif.clk);
        while (!vif.reset_n) @(posedge vif.clk);
        forever begin
            @(vif.rx_monitor_cb);
            if (vif.rx_monitor_cb.md_rx_valid && vif.rx_monitor_cb.md_rx_ready) begin
                rx_transaction tr = rx_transaction::type_id::create("rx_tr");
                tr.data   = vif.rx_monitor_cb.md_rx_data;
                tr.offset = vif.rx_monitor_cb.md_rx_offset;
                tr.size   = vif.rx_monitor_cb.md_rx_size;
                tr.valid  = vif.rx_monitor_cb.md_rx_valid;
                tr.err    = vif.rx_monitor_cb.md_rx_err;
                `uvm_info("RX_MON", tr.convert2string(), UVM_HIGH)
                ap.write(tr);
            end
        end
    endtask

endclass : rx_monitor


// =============================================================================
// rx_agent.sv
// Agente RX: agrupa sequencer + driver + monitor
// =============================================================================

class rx_agent extends uvm_agent;
    `uvm_component_utils(rx_agent)

    uvm_sequencer #(rx_transaction) sequencer;
    rx_driver  driver;
    rx_monitor monitor;
    uvm_analysis_port #(rx_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap        = new("ap", this);
        sequencer = uvm_sequencer #(rx_transaction)::type_id::create("sequencer", this);
        driver    = rx_driver::type_id::create("driver", this);
        monitor   = rx_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
        monitor.ap.connect(ap);
    endfunction

endclass : rx_agent
