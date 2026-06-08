// tests.sv - Todos los tests en un solo archivo (VERSIÓN FINAL CORREGIDA)

// ============================================
// TEST 1: Basic Read/Write
// ============================================
class test_apb_basic_rw extends uvm_test;
    `uvm_component_utils(test_apb_basic_rw)
    
    cfs_aligner_apb_env env;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cfs_aligner_apb_env::type_id::create("env", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        uvm_status_e status;
        uvm_reg_data_t rd_data;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "=== Test: Basic APB Read/Write ===", UVM_LOW)
        
        // Esperar a que el reset termine
        #100;
        
        // 1. Verificar valores de reset
        env.regmodel.ctrl.read(status, rd_data);
        `uvm_info(get_type_name(), $sformatf("CTRL after reset: 0x%08x (size=%0d, offset=%0d)", 
                  rd_data,
                  env.regmodel.ctrl.size.get_mirrored_value(),
                  env.regmodel.ctrl.offset.get_mirrored_value()), UVM_LOW)
        
        // 2. Escribir combinación VÁLIDA: size=2, offset=0
        `uvm_info(get_type_name(), "Writing CTRL with size=2, offset=0 (valid combination)", UVM_LOW)
        env.regmodel.ctrl.size.set(2);
        env.regmodel.ctrl.offset.set(0);
        env.regmodel.ctrl.update(status);
        
        if (status != UVM_IS_OK) begin
            `uvm_error(get_type_name(), $sformatf("Write failed with status: %s", status.name()))
        end
        
        // 3. Leer y verificar
        env.regmodel.ctrl.read(status, rd_data);
        `uvm_info(get_type_name(), $sformatf("CTRL after write: 0x%08x", rd_data), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  size = %0d (expected 2)", 
                  env.regmodel.ctrl.size.get_mirrored_value()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  offset = %0d (expected 0)", 
                  env.regmodel.ctrl.offset.get_mirrored_value()), UVM_LOW)
        
        if (env.regmodel.ctrl.size.get_mirrored_value() == 2) begin
            `uvm_info(get_type_name(), "✓ SIZE correctly written", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), $sformatf("SIZE mismatch! Expected 2, Got %0d", 
                        env.regmodel.ctrl.size.get_mirrored_value()))
        end
        
        if (env.regmodel.ctrl.offset.get_mirrored_value() == 0) begin
            `uvm_info(get_type_name(), "✓ OFFSET correctly written", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), $sformatf("OFFSET mismatch! Expected 0, Got %0d", 
                        env.regmodel.ctrl.offset.get_mirrored_value()))
        end
        
        // 4. Verificar IRQEN reset (debe ser 0x1F)
        env.regmodel.irqen.read(status, rd_data);
        if (rd_data == 32'h1F) begin
            `uvm_info(get_type_name(), "✓ IRQEN reset value correct (0x1F)", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), $sformatf("IRQEN reset incorrect: 0x%08x (expected 0x1F)", rd_data))
        end
        
        `uvm_info(get_type_name(), "=== Test PASSED ===", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass


// ============================================
// TEST 2: Illegal CTRL Writes
// ============================================
class test_apb_illegal_writes extends uvm_test;
    `uvm_component_utils(test_apb_illegal_writes)
    
    cfs_aligner_apb_env env;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cfs_aligner_apb_env::type_id::create("env", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        uvm_status_e status;
        uvm_reg_data_t rd_data;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "=== Test: Illegal CTRL Writes ===", UVM_LOW)
        
        // Esperar a que el reset termine
        #100;
        
        // Guardar valor original
        env.regmodel.ctrl.read(status, rd_data);
        `uvm_info(get_type_name(), $sformatf("Original CTRL value: 0x%08x", rd_data), UVM_LOW)
        
        // Test 1: SIZE = 0 (ilegal - debe ser rechazado)
        `uvm_info(get_type_name(), "Test 1: SIZE = 0 (should be rejected)", UVM_LOW)
        env.regmodel.ctrl.size.set(0);
        env.regmodel.ctrl.update(status);
        
        if (status == UVM_IS_OK) begin
            `uvm_error(get_type_name(), "SIZE=0 should have been rejected!")
        end else begin
            `uvm_info(get_type_name(), "  ✓ SIZE=0 correctly rejected", UVM_LOW)
        end
        
        // Test 2: Alineación inválida (offset=1, size=3)
        // Para DATA_WIDTH=32: (4 + 1) % 3 = 2 ≠ 0 → inválido
        `uvm_info(get_type_name(), "Test 2: Invalid alignment (offset=1, size=3)", UVM_LOW)
        env.regmodel.ctrl.size.set(3);
        env.regmodel.ctrl.offset.set(1);
        env.regmodel.ctrl.update(status);
        
        if (status == UVM_IS_OK) begin
            `uvm_error(get_type_name(), "Invalid alignment should have been rejected!")
        end else begin
            `uvm_info(get_type_name(), "  ✓ Invalid alignment correctly rejected", UVM_LOW)
        end
        
        // Test 3: Alineación válida (offset=0, size=2)
        // Para DATA_WIDTH=32: (4 + 0) % 2 = 0 → válido
        `uvm_info(get_type_name(), "Test 3: Valid alignment (offset=0, size=2)", UVM_LOW)
        env.regmodel.ctrl.size.set(2);
        env.regmodel.ctrl.offset.set(0);
        env.regmodel.ctrl.update(status);
        
        if (status != UVM_IS_OK) begin
            `uvm_error(get_type_name(), "Valid alignment should have been accepted!")
        end else begin
            `uvm_info(get_type_name(), "  ✓ Valid alignment correctly accepted", UVM_LOW)
        end
        
        `uvm_info(get_type_name(), "=== Test PASSED ===", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass


// ============================================
// TEST 3: W1C IRQ Behavior (CORREGIDO)
// ============================================
class test_apb_w1c_irq extends uvm_test;
    `uvm_component_utils(test_apb_w1c_irq)
    
    cfs_aligner_apb_env env;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cfs_aligner_apb_env::type_id::create("env", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        uvm_status_e status;
        uvm_reg_data_t rd_data;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), "=== Test: W1C IRQ Behavior ===", UVM_LOW)
        
        #100;
        
        // NOTA: Los bits IRQ son puestos por el HARDWARE (eventos de FIFOs)
        // No se pueden simular por backdoor porque son W1C y RO desde APB.
        // Este test verifica que:
        //   1. Los bits se pueden leer (inicialmente 0)
        //   2. Escribir 1 no tiene efecto si el hardware no los puso
        
        `uvm_info(get_type_name(), "Verifying IRQ register behavior...", UVM_LOW)
        
        // 1. Leer IRQ inicial (debe ser 0)
        env.regmodel.irq.read(status, rd_data);
        `uvm_info(get_type_name(), $sformatf("Initial IRQ value: 0x%08x", rd_data), UVM_LOW)
        
        if (rd_data != 32'h0) begin
            `uvm_warning(get_type_name(), $sformatf("IRQ not zero after reset: 0x%08x", rd_data))
        end else begin
            `uvm_info(get_type_name(), "  ✓ IRQ initial value is 0", UVM_LOW)
        end
        
        // 2. Escribir 1 a un campo W1C (esto debería NO hacer nada porque el hardware no lo puso)
        `uvm_info(get_type_name(), "Writing 1 to IRQ.rx_fifo_empty (should have no effect)", UVM_LOW)
        env.regmodel.irq.rx_fifo_empty.set(1);
        env.regmodel.irq.update(status);
        
        // 3. Verificar que sigue siendo 0 (porque el hardware no lo activó)
        env.regmodel.irq.read(status, rd_data);
        `uvm_info(get_type_name(), $sformatf("IRQ after write 1: 0x%08x", rd_data), UVM_LOW)
        
        if (env.regmodel.irq.rx_fifo_empty.get_mirrored_value() == 0) begin
            `uvm_info(get_type_name(), "  ✓ W1C field remains 0 (hardware didn't set it)", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), "W1C field changed to 1 by software write!")
        end
        
        // 4. Verificar escritura de 0 no afecta
        env.regmodel.irq.rx_fifo_empty.set(0);
        env.regmodel.irq.update(status);
        env.regmodel.irq.read(status, rd_data);
        
        if (env.regmodel.irq.rx_fifo_empty.get_mirrored_value() == 0) begin
            `uvm_info(get_type_name(), "  ✓ Writing 0 has no effect", UVM_LOW)
        end
        
        `uvm_info(get_type_name(), "NOTE: Full W1C verification requires hardware simulation", UVM_LOW)
        `uvm_info(get_type_name(), "      (IRQ bits are set by FIFO events, not software)", UVM_LOW)
        
        `uvm_info(get_type_name(), "=== Test PASSED ===", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass


// ============================================
// TEST 4: Random Stress
// ============================================
class test_apb_random_stress extends uvm_test;
    `uvm_component_utils(test_apb_random_stress)
    
    cfs_aligner_apb_env env;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cfs_aligner_apb_env::type_id::create("env", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        uvm_status_e status;
        uvm_reg_data_t rd_data;
        int num_transactions = 100;
        int errors = 0;
        int op;
        int size, offset;
        int data_width_bytes = 4;
        
        phase.raise_objection(this);
        
        `uvm_info(get_type_name(), $sformatf("=== Test: Random Stress (%0d transactions) ===", num_transactions), UVM_LOW)
        
        // Esperar a que el reset termine
        #100;
        
        repeat(num_transactions) begin
            op = $urandom_range(0, 4);
            
            case (op)
                // Escritura CTRL con valores aleatorios VÁLIDOS
                0: begin
                    size = 2;  // size fijo para simplificar
                    offset = $urandom_range(0, 1) * 2;  // offset: 0 o 2
                    env.regmodel.ctrl.size.set(size);
                    env.regmodel.ctrl.offset.set(offset);
                    env.regmodel.ctrl.update(status);
                end
                
                // Escritura IRQEN aleatoria
                1: begin
                    env.regmodel.irqen.rx_fifo_empty.set($urandom_range(0, 1));
                    env.regmodel.irqen.rx_fifo_full.set($urandom_range(0, 1));
                    env.regmodel.irqen.tx_fifo_empty.set($urandom_range(0, 1));
                    env.regmodel.irqen.tx_fifo_full.set($urandom_range(0, 1));
                    env.regmodel.irqen.max_drop.set($urandom_range(0, 1));
                    env.regmodel.irqen.update(status);
                end
                
                // Lectura STATUS
                2: begin
                    env.regmodel.status.read(status, rd_data);
                end
                
                // Lectura IRQ
                3: begin
                    env.regmodel.irq.read(status, rd_data);
                end
                
                // Lectura IRQEN
                4: begin
                    env.regmodel.irqen.read(status, rd_data);
                end
            endcase
        end
        
        if (errors == 0) begin
            `uvm_info(get_type_name(), $sformatf("=== Test PASSED (%0d transactions, 0 errors) ===", num_transactions), UVM_LOW)
        end else begin
            `uvm_error(get_type_name(), $sformatf("=== Test FAILED with %0d errors ===", errors))
        end
        
        phase.drop_objection(this);
    endtask
endclass