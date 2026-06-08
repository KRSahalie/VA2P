// scoreboard.sv
`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

package scoreboard_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import aligner_tb_pkg::*;

    class ref_model;
        // Configuración actual
        logic [1:0] cfg_offset;
        logic [2:0] cfg_size;
        localparam int BYTES_PER_WORD = 4;
        
        // Buffer de datos no alineados (bytes pendientes)
        logic [7:0] pending_bytes[$];
        
        // Estadísticas
        int tx_packets_generated = 0;
        int rx_packets_consumed  = 0;
        
        function new();
            cfg_offset = 2'b00;
            cfg_size   = 3'd4;
        endfunction
        
        function void set_config(logic [1:0] offset, logic [2:0] size);
            cfg_offset = offset;
            cfg_size   = size;
        endfunction
        
        // Procesar un paquete RX y generar los TX esperados
        function void process_rx_packet(rx_transaction rx, ref tx_transaction tx_queue[$]);
            logic [7:0] rx_bytes[0:3];
            int src_byte_idx;
            
            // Extraer bytes del dato RX (little-endian)
            for (int i = 0; i < BYTES_PER_WORD; i++) begin
                rx_bytes[i] = rx.data[i*8 +: 8];
            end
            
            // Extraer bytes válidos según offset y size del RX
            for (int i = 0; i < rx.size; i++) begin
                src_byte_idx = rx.offset + i;
                if (src_byte_idx < BYTES_PER_WORD) begin
                    pending_bytes.push_back(rx_bytes[src_byte_idx]);
                end
            end
            
            // Generar tantos TX como sea posible con los bytes pendientes
            while (pending_bytes.size() >= cfg_size) begin
                tx_transaction tx = tx_transaction::type_id::create("tx");
                tx.size   = cfg_size;
                tx.offset = cfg_offset;
                tx.valid  = 1;
                tx.err    = 0;
                tx.data = 32'h0;
                for (int i = 0; i < cfg_size; i++) begin
                    tx.data[(cfg_offset + i) * 8 +: 8] = pending_bytes[i];
                end
                
                // Remover bytes usados del pending buffer
                for (int i = 0; i < cfg_size; i++) begin
                    pending_bytes.pop_front();
                end
                
                tx_queue.push_back(tx);
                tx_packets_generated++;
            end
            
            rx_packets_consumed++;
        endfunction
        
        // Limpiar el modelo (reset)
        function void reset();
            pending_bytes.delete();
            tx_packets_generated = 0;
            rx_packets_consumed  = 0;
        endfunction
        
        // Obtener bytes pendientes
        function int get_pending_count();
            return pending_bytes.size();
        endfunction
        
        // Verificar si un paquete RX debe ser dropeado
        function bit should_drop(rx_transaction rx);
            if (rx.size == 0) return 1;
            return (( (BYTES_PER_WORD + rx.offset) % rx.size ) != 0);
        endfunction
    endclass : ref_model

    class scoreboard extends uvm_scoreboard;
        `uvm_component_utils(scoreboard)

        uvm_analysis_imp_rx  #(rx_transaction,  scoreboard) rx_export;
        uvm_analysis_imp_tx  #(tx_transaction,  scoreboard) tx_export;
        uvm_analysis_imp_irq #(irq_transaction, scoreboard) irq_export;

        // Modelo de referencia
        ref_model model;
        
        // Colas para comparación
        tx_transaction expected_tx_queue[$];
        
        // Contadores
        int expected_drop_count = 0;
        int rx_packet_count     = 0;
        int tx_match_count      = 0;
        int tx_mismatch_count   = 0;
        int error_count         = 0;
        
        // Para verificación final
        int actual_drop_count = 0;
        int irq_count         = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            model = new();
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            rx_export  = new("rx_export",  this);
            tx_export  = new("tx_export",  this);
            irq_export = new("irq_export", this);
        endfunction

        function void set_cfg(logic [1:0] off, logic [2:0] sz);
            model.set_config(off, sz);
            `uvm_info(get_type_name(),
                $sformatf("Config actualizada: offset=%0d size=%0d", off, sz), UVM_LOW)
        endfunction

        function void write_rx(rx_transaction tr);
            bit should_drop;
            rx_packet_count++;
            
            should_drop = model.should_drop(tr);
            
            `uvm_info(get_type_name(),
                $sformatf("[RX] #%0d: data=0x%08X off=%0d size=%0d err=%0b should_drop=%0b",
                          rx_packet_count, tr.data, tr.offset, tr.size,
                          tr.err, should_drop), UVM_MEDIUM)
            
            if (tr.err) begin
                if (!should_drop) begin
                    `uvm_error(get_type_name(), $sformatf(
                        "FALSO DROP: RX#%0d data=0x%08X off=%0d size=%0d -> DUT marcó error pero debería ser válido",
                        rx_packet_count, tr.data, tr.offset, tr.size))
                    error_count++;
                end else begin
                    expected_drop_count++;
                    `uvm_info(get_type_name(),
                        $sformatf("DROP OK: RX#%0d off=%0d size=%0d",
                                  rx_packet_count, tr.offset, tr.size), UVM_LOW)
                end
            end else begin
                if (should_drop) begin
                    `uvm_error(get_type_name(), $sformatf(
                        "DROP PERDIDO: RX#%0d data=0x%08X off=%0d size=%0d -> DUT NO marcó error pero debería",
                        rx_packet_count, tr.data, tr.offset, tr.size))
                    error_count++;
                end else begin
                    model.process_rx_packet(tr, expected_tx_queue);
                    `uvm_info(get_type_name(),
                        $sformatf("RX PROCESADO: #%0d, pending_bytes=%0d, expected_tx=%0d",
                                  rx_packet_count, model.get_pending_count(),
                                  expected_tx_queue.size()), UVM_HIGH)
                end
            end
        endfunction

        function void write_tx(tx_transaction tr);
            tx_transaction expected;
            
            `uvm_info(get_type_name(),
                $sformatf("[TX] data=0x%08X off=%0d size=%0d", tr.data, tr.offset, tr.size),
                UVM_MEDIUM)
            
            if (tr.offset !== model.cfg_offset) begin
                `uvm_error(get_type_name(),
                    $sformatf("TX OFFSET INCORRECTO: recibido=%0d esperado=%0d (CTRL.OFFSET)",
                              tr.offset, model.cfg_offset))
                error_count++;
                return;
            end
            
            if (expected_tx_queue.size() == 0) begin
                `uvm_error(get_type_name(), $sformatf(
                    "TX INESPERADO: data=0x%08X size=%0d (no hay TX esperado en cola)",
                    tr.data, tr.size))
                tx_mismatch_count++;
                error_count++;
                return;
            end
            
            expected = expected_tx_queue.pop_front();
            
            // Comparar datos y tamaño
            if (tr.data !== expected.data) begin
                `uvm_error(get_type_name(), $sformatf(
                    "TX DATA MISMATCH:\n  Esperado: 0x%08X\n  Recibido: 0x%08X\n  rx_packets=%0d, tx_packets_model=%0d",
                    expected.data, tr.data,
                    model.rx_packets_consumed, model.tx_packets_generated))
                error_count++;
                tx_mismatch_count++;
            end else if (tr.size !== expected.size) begin
                `uvm_error(get_type_name(), $sformatf(
                    "TX SIZE MISMATCH: esperado=%0d recibido=%0d",
                    expected.size, tr.size))
                error_count++;
                tx_mismatch_count++;
            end else begin
                `uvm_info(get_type_name(),
                    $sformatf("TX MATCH OK: data=0x%08X size=%0d", tr.data, tr.size),
                    UVM_MEDIUM)
                tx_match_count++;
            end
        endfunction

        function void write_irq(irq_transaction tr);
            irq_count++;
            `uvm_info(get_type_name(),
                $sformatf("[IRQ #%0d] @ %0t", irq_count, tr.timestamp), UVM_LOW)
        endfunction

        function void set_actual_drops(int drops);
            actual_drop_count = drops;
            if (expected_drop_count != actual_drop_count) begin
                `uvm_error(get_type_name(), $sformatf(
                    "CNT_DROP MISMATCH: esperado=%0d leído=%0d",
                    expected_drop_count, actual_drop_count))
                error_count++;
            end else begin
                `uvm_info(get_type_name(),
                    $sformatf("CNT_DROP OK: %0d", actual_drop_count), UVM_LOW)
            end
        endfunction

        function void check_phase(uvm_phase phase);
            if (expected_tx_queue.size() > 0) begin
                `uvm_error(get_type_name(), $sformatf(
                    "TX PENDIENTES EN MODELO: %0d TX esperados no se recibieron",
                    expected_tx_queue.size()))
                error_count++;
            end
            
            if (model.get_pending_count() > 0) begin
                `uvm_warning(get_type_name(), $sformatf(
                    "BYTES PENDIENTES EN MODELO: %0d (puede ser normal si el test terminó abruptamente)",
                    model.get_pending_count()))
            end
            
            `uvm_info(get_type_name(), $sformatf(
                "\n==========================================\n  RESUMEN SCOREBOARD\n==========================================\n  RX packets recibidos:   %0d\n  Drops esperados:        %0d\n  Drops reales (CNT_DROP):%0d\n  TX generados (modelo):  %0d\n  TX recibidos:           %0d\n  TX correctos:           %0d\n  TX incorrectos:         %0d\n  IRQs recibidas:         %0d\n  Errores totales:        %0d\n==========================================",
                rx_packet_count,
                expected_drop_count,
                actual_drop_count,
                model.tx_packets_generated,
                tx_match_count + tx_mismatch_count,
                tx_match_count,
                tx_mismatch_count,
                irq_count,
                error_count), UVM_NONE)
            
            if (error_count > 0) begin
                `uvm_error(get_type_name(), "TEST FALLIDO")
            end else begin
                `uvm_info(get_type_name(), "TEST PASADO", UVM_NONE)
            end
        endfunction

        function void reset_counters();
            expected_tx_queue.delete();
            model.reset();
            expected_drop_count = 0;
            actual_drop_count   = 0;
            rx_packet_count     = 0;
            tx_match_count      = 0;
            tx_mismatch_count   = 0;
            error_count         = 0;
            irq_count           = 0;
        endfunction
        
        function void print_model_status();
            `uvm_info(get_type_name(), $sformatf(
                "MODEL STATUS: pending_bytes=%0d, tx_generated=%0d, rx_consumed=%0d",
                model.get_pending_count(),
                model.tx_packets_generated,
                model.rx_packets_consumed), UVM_LOW)
        endfunction
    endclass : scoreboard

endpackage : scoreboard_pkg

`endif // SCOREBOARD_SV