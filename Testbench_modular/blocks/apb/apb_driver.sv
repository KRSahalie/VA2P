// =============================================================================
// apb_driver.sv
// Driver APB — 
//
// Implementa el protocolo APB3 completo usando solo el clocking block apb_cb:
//   1. Setup phase  : psel=1, pwrite, paddr, pwdata, penable=0
//   2. Access phase : penable=1
//   3. Wait pready
//   4. Idle         : psel=0, penable=0
//
// Fix aplicado [FIX-APB]: usa solo vif.apb_cb (clocking block) para evitar
// hazards de timing con señales directas de la interface.
// =============================================================================

class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)
    virtual aligner_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aligner_if)::get(
                this, "", "apb_vif", vif))
            `uvm_fatal("APB_DRV", "No se encontró apb_vif")
    endfunction

    task run_phase(uvm_phase phase);
        // Idle inicial
        vif.apb_cb.psel    <= 0;
        vif.apb_cb.penable <= 0;
        vif.apb_cb.pwrite  <= 0;
        vif.apb_cb.paddr   <= 0;
        vif.apb_cb.pwdata  <= 0;
        @(posedge vif.clk);
        while (!vif.reset_n) @(posedge vif.clk);
        repeat(2) @(vif.apb_cb);
        `uvm_info("APB_DRV", "Reset liberado, APB listo", UVM_LOW)
        forever begin
            apb_transaction tr;
            seq_item_port.get_next_item(tr);
            drive_apb(tr);
            seq_item_port.item_done(tr);
        end
    endtask

    task drive_apb(apb_transaction tr);
        // Setup phase
        @(vif.apb_cb);
        vif.apb_cb.psel    <= 1;
        vif.apb_cb.pwrite  <= tr.write;
        vif.apb_cb.paddr   <= tr.addr;
        vif.apb_cb.pwdata  <= tr.data;
        vif.apb_cb.penable <= 0;
        // Access phase
        @(vif.apb_cb);
        vif.apb_cb.penable <= 1;
        // Esperar pready
        @(vif.apb_cb);
        while (!vif.apb_cb.pready) @(vif.apb_cb);
        tr.slverr = vif.apb_cb.pslverr;
        if (!tr.write) tr.data = vif.apb_cb.prdata;
        // Idle
        @(vif.apb_cb);
        vif.apb_cb.psel    <= 0;
        vif.apb_cb.penable <= 0;
        vif.apb_cb.pwrite  <= 0;
        vif.apb_cb.paddr   <= 0;
        vif.apb_cb.pwdata  <= 0;
    endtask

endclass : apb_driver
