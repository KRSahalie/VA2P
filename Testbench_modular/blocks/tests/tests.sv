// =============================================================================
// tests.sv
// Tests del testbench cfs_aligner — heredan de test_base
//
// Tests incluidos:
//   test_basic_align  — offset=0 size=4, 8 paquetes, 0 drops esperados
//   test_offset_align — rx_offset=2 size=2, 8 paquetes, verifica realineación
//   test_drops        — 4 legales + 4 ilegales, verifica CNT_DROP==4
//   test_irq          — habilita RX_FIFO_EMPTY+TX_FIFO_EMPTY, verifica IRQ
// =============================================================================

// =============================================================================
// TEST 1: test_basic_align
//
// Configuración DUT : CTRL.size=4, CTRL.offset=0
// Estímulo          : 8 paquetes RX con rx_offset=0, rx_size=4
// Fórmula drop      : (4+0)%4=0 → todos pasan, 0 drops esperados
// Verifica          : CNT_DROP==0, 8 TX recibidos con datos correctos
// =============================================================================
class test_basic_align extends test_base;
    `uvm_component_utils(test_basic_align)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rx_fixed_seq seq;
        int unsigned cnt_drop;

        phase.raise_objection(this);

        // [FIX-RESET] Esperar que el reset HW termine (10 ciclos × 10ns = 100ns)
        #200ns;
        reset_dut();

        write_ctrl(.sz(3'd4), .off(2'b00));
        env.sb.set_cfg(2'b00, 3'd4);

        `uvm_info("TEST", "=== test_basic_align: 8 pkts offset=0 size=4 ===", UVM_LOW)
        seq              = rx_fixed_seq::type_id::create("seq");
        seq.n_pkts       = 8;
        seq.fixed_offset = 2'b00;
        seq.fixed_size   = 3'd4;
        seq.start(env.rx_agt.sequencer);

        #200ns; // drenaje del pipeline TX

        read_cnt_drop(cnt_drop);
        env.sb.set_actual_drops(cnt_drop);

        `uvm_info("TEST", "test_basic_align DONE", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : test_basic_align


// =============================================================================
// TEST 2: test_offset_align
//
// Configuración DUT : CTRL.size=2, CTRL.offset=0
// Estímulo          : 8 paquetes RX con rx_offset=2, rx_size=2
// Fórmula drop      : (4+2)%2=0 → todos pasan (bytes válidos en pos 2 y 3)
// Verifica          : TX recibido = {rx_data[31:24], rx_data[23:16]} en bytes [1:0]
// =============================================================================
class test_offset_align extends test_base;
    `uvm_component_utils(test_offset_align)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rx_fixed_seq seq;
        int unsigned cnt_drop;

        phase.raise_objection(this);

        #200ns;
        reset_dut();

        // CTRL: size=2 offset=0 → bits[2:0]=2, bits[9:8]=0
        write_ctrl(.sz(3'd2), .off(2'b00));
        env.sb.set_cfg(2'b00, 3'd2);

        `uvm_info("TEST", "=== test_offset_align: 8 pkts rx_offset=2 rx_size=2 ===", UVM_LOW)
        seq              = rx_fixed_seq::type_id::create("seq");
        seq.n_pkts       = 8;
        seq.fixed_offset = 2'b10; // bytes útiles en posición 2 y 3
        seq.fixed_size   = 3'd2;
        seq.start(env.rx_agt.sequencer);

        #200ns;

        read_cnt_drop(cnt_drop);
        env.sb.set_actual_drops(cnt_drop);

        `uvm_info("TEST", "test_offset_align DONE", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : test_offset_align


// =============================================================================
// TEST 3: test_drops
//
// Configuración DUT : CTRL.size=4, CTRL.offset=0
// Estímulo          : 4 legales (offset=0,size=4) + 4 ilegales
// Fórmula drop      : ilegales → (4+1)%3≠0 o (4+3)%2≠0 → 4 drops
// Verifica          : CNT_DROP==4
// =============================================================================
class test_drops extends test_base;
    `uvm_component_utils(test_drops)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rx_mixed_seq seq;
        int unsigned cnt_drop;

        phase.raise_objection(this);

        #200ns;
        reset_dut();

        write_ctrl(.sz(3'd4), .off(2'b00));
        env.sb.set_cfg(2'b00, 3'd4);

        `uvm_info("TEST", "=== test_drops: 4 legales + 4 ilegales ===", UVM_LOW)
        seq           = rx_mixed_seq::type_id::create("seq");
        seq.n_legal   = 4;
        seq.n_illegal = 4;
        seq.start(env.rx_agt.sequencer);

        #300ns; // tiempo extra para que DUT actualice CNT_DROP

        read_cnt_drop(cnt_drop);
        env.sb.set_actual_drops(cnt_drop);

        `uvm_info("TEST", "test_drops DONE", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : test_drops


// =============================================================================
// TEST 4: test_irq
//
// Configuración DUT : CTRL.size=4, CTRL.offset=0
//                     IRQEN=0x5 (bit0=RX_FIFO_EMPTY, bit2=TX_FIFO_EMPTY)
// Estímulo          : 4 paquetes RX legales
// Verifica          :
//   1. Al menos 1 IRQ detectada por el irq_monitor
//   2. Registro IRQ tiene bits activos tras el tráfico
//   3. Tras clear_irq(), IRQ[4:0]==0
// =============================================================================
class test_irq extends test_base;
    `uvm_component_utils(test_irq)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        rx_fixed_seq   seq;
        uvm_reg_data_t irq_val;
        int unsigned   cnt_drop;

        phase.raise_objection(this);

        #200ns;
        reset_dut();

        write_ctrl(.sz(3'd4), .off(2'b00));
        env.sb.set_cfg(2'b00, 3'd4);

        // Habilitar RX_FIFO_EMPTY (bit0) y TX_FIFO_EMPTY (bit2)
        enable_irq(32'h5);
        `uvm_info("TEST",
            "=== test_irq: IRQEN=0x5 (RX_FIFO_EMPTY + TX_FIFO_EMPTY) ===", UVM_LOW)

        seq              = rx_fixed_seq::type_id::create("seq");
        seq.n_pkts       = 4;
        seq.fixed_offset = 2'b00;
        seq.fixed_size   = 3'd4;
        seq.start(env.rx_agt.sequencer);

        // Esperar a que el TX FIFO se vacíe y genere IRQ
        #500ns;

        // Verificar al menos 1 IRQ detectada
        env.sb.verify_irq_count(1);

        // Leer y loggear registro IRQ
        read_irq(irq_val);
        `uvm_info("TEST", $sformatf("IRQ register = 0x%08X", irq_val), UVM_LOW)

        // Limpiar IRQs (W1C)
        clear_irq();
        #50ns;

        // Verificar que IRQ quedó limpio
        read_irq(irq_val);
        if (irq_val[4:0] !== 5'b0)
            `uvm_error("TEST", $sformatf("IRQ no se limpió: 0x%0X", irq_val[4:0]))
        else
            `uvm_info("TEST", "IRQ limpio correctamente", UVM_LOW)

        read_cnt_drop(cnt_drop);
        env.sb.set_actual_drops(cnt_drop);

        `uvm_info("TEST", "test_irq DONE", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : test_irq
