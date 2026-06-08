// =============================================================================
// test_base.sv
// Clase base para todos los tests del testbench cfs_aligner
//
// Responsabilidades:
//   · Instancia y registra el reg_model (RAL)
//   · Instancia el environment y el tx_ready_driver
//   · Provee tasks de acceso al RAL listos para usar en tests derivados:
//       write_ctrl()      — escribe CTRL con value de 32 bits correcto
//       read_cnt_drop()   — lee STATUS completo y extrae bits[7:0]
//       read_irq()        — lee IRQ completo (32 bits)
//       clear_irq()       — limpia todos los bits W1C de IRQ
//       disable_irq()     — pone IRQEN=0
//       enable_irq(mask)  — pone IRQEN=mask
//       reset_dut()       — deshabilita IRQ + limpia IRQ (llamar tras 200ns)
//
// [FIX-W1] Todos los accesos RAL usan write/read al registro completo
//          con máscaras — NO se usa field.write() ni field.read() para
//          evitar el warning "Individual field access not available".
//
// [FIX-W2] write_ctrl() construye el valor 32 bits explícitamente:
//          bits[2:0]=size, bits[9:8]=offset, resto=0.
//          Así no se toca el campo WO CLR (bit16) ni reservados,
//          evitando PSLVERR por escritura ilegal.
//
// [FIX-RESET] reset_dut() debe llamarse DESPUÉS de esperar ≥200ns desde
//             el inicio de la simulación para que el reset HW haya terminado.
// =============================================================================

class test_base extends uvm_test;
    `uvm_component_utils(test_base)

    aligner_env      env;
    tx_ready_driver  tx_rdy;
    cfs_aligner_regs reg_model;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        reg_model = new("reg_model");
        reg_model.build();
        reg_model.lock_model();
        uvm_config_db #(cfs_aligner_regs)::set(this, "*", "reg_model", reg_model);
        env    = aligner_env::type_id::create("env",    this);
        tx_rdy = tx_ready_driver::type_id::create("tx_rdy", this);
    endfunction

    // -------------------------------------------------------------------------
    // [FIX-W1][FIX-W2]
    // Escribe CTRL con valor de 32 bits correcto:
    //   bits[2:0]  = size   (campo RW)
    //   bits[9:8]  = offset (campo RW)
    //   resto      = 0      (reservados y CLR en 0 → no activa clear)
    // -------------------------------------------------------------------------
    task write_ctrl(logic [2:0] sz, logic [1:0] off);
        uvm_status_e status;
        logic [31:0] val;
        val      = 32'h0;
        val[2:0] = sz;
        val[9:8] = off;
        reg_model.ctrl.write(status, val);
        if (status != UVM_IS_OK)
            `uvm_error("TEST", $sformatf(
                "CTRL write falló (size=%0d offset=%0d) — combinación ilegal?", sz, off))
        else
            `uvm_info("TEST", $sformatf(
                "CTRL configurado: size=%0d offset=%0d", sz, off), UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // [FIX-W1] Lee STATUS completo y extrae CNT_DROP con máscara [7:0]
    // -------------------------------------------------------------------------
    task read_cnt_drop(output int unsigned cnt);
        uvm_status_e   status;
        uvm_reg_data_t val;
        reg_model.status.read(status, val);
        cnt = int'(val[7:0]);
    endtask

    // -------------------------------------------------------------------------
    // [FIX-W1] Lee IRQ completo y devuelve los 32 bits
    // -------------------------------------------------------------------------
    task read_irq(output uvm_reg_data_t val);
        uvm_status_e status;
        reg_model.irq.read(status, val);
    endtask

    // Limpia IRQ escribiendo 1 en todos los bits W1C (bits[4:0])
    task clear_irq();
        uvm_status_e status;
        reg_model.irq.write(status, 32'h1F);
    endtask

    // Deshabilita todas las interrupciones (IRQEN=0)
    task disable_irq();
        uvm_status_e status;
        reg_model.irqen.write(status, 32'h0);
    endtask

    // Habilita interrupciones según máscara (IRQEN=mask)
    task enable_irq(logic [31:0] mask);
        uvm_status_e status;
        reg_model.irqen.write(status, mask);
    endtask

    // -------------------------------------------------------------------------
    // reset_dut: limpia IRQ y deshabilita interrupciones para test limpio
    // [FIX-RESET] Llamar solo DESPUÉS de #200ns desde el inicio
    // -------------------------------------------------------------------------
    task reset_dut();
        `uvm_info("TEST", "=== reset_dut START ===", UVM_LOW)
        disable_irq();
        clear_irq();
        `uvm_info("TEST", "=== reset_dut DONE ===", UVM_LOW)
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        phase.drop_objection(this);
    endtask

endclass : test_base
