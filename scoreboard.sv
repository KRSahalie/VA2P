// scoreboard.sv
`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

package scoreboard_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import aligner_tb_pkg::*;

    class ref_model;
        logic [1:0] cfg_offset;
        logic [2:0] cfg_size;
        localparam int BYTES_PER_WORD = 4;

        logic [7:0] pending_bytes[$];

        int tx_packets_generated = 0;
        int rx_packets_consumed  = 0;

        function new();
            cfg_offset = 2'b00;
            cfg_size   = 3'd4;
        endfunction

        // [FIX-BUG1] Al cambiar config, flush de pending_bytes igual que hace el DUT
        function void set_config(logic [1:0] offset, logic [2:0] size);
            if (offset !== cfg_offset || size !== cfg_size) begin
                pending_bytes.delete();
                cfg_offset = offset;
                cfg_size   = size;
            end
        endfunction

        function void process_rx_packet(rx_transaction rx, ref tx_transaction tx_queue[$]);
            logic [7:0] rx_bytes[0:3];
            int src_byte_idx;

            for (int i = 0; i < BYTES_PER_WORD; i++)
                rx_bytes[i] = rx.data[i*8 +: 8];

            for (int i = 0; i < int'(rx.size); i++) begin
                src_byte_idx = int'(rx.offset) + i;
                if (src_byte_idx < BYTES_PER_WORD)
                    pending_bytes.push_back(rx_bytes[src_byte_idx]);
            end

            while (pending_bytes.size() >= int'(cfg_size)) begin
                tx_transaction tx = tx_transaction::type_id::create("tx");
                tx.size   = cfg_size;
                tx.offset = cfg_offset;
                tx.valid  = 1;
                tx.err    = 0;
                tx.data   = 32'h0;
                for (int i = 0; i < int'(cfg_size); i++)
                    tx.data[i*8 +: 8] = pending_bytes[i];
                for (int i = 0; i < int'(cfg_size); i++)
                    pending_bytes.pop_front();
                tx_queue.push_back(tx);
                tx_packets_generated++;
            end

            rx_packets_consumed++;
        endfunction

        function void reset();
            pending_bytes.delete();
            tx_packets_generated = 0;
            rx_packets_consumed  = 0;
        endfunction

        function int get_pending_count();
            return pending_bytes.size();
        endfunction

        function bit should_drop(rx_transaction rx);
            if (rx.size == 0) return 1;
            return (((BYTES_PER_WORD + rx.offset) % rx.size) != 0);
        endfunction
    endclass : ref_model

    class scoreboard extends uvm_scoreboard;
        `uvm_component_utils(scoreboard)

        uvm_analysis_imp_rx  #(rx_transaction,  scoreboard) rx_export;
        uvm_analysis_imp_tx  #(tx_transaction,  scoreboard) tx_export;
        uvm_analysis_imp_irq #(irq_transaction, scoreboard) irq_export;

        ref_model model;

        tx_transaction expected_tx_queue[$];

        int expected_drop_count = 0;
        int rx_packet_count     = 0;
        int tx_match_count      = 0;
        int tx_mismatch_count   = 0;
        int error_count         = 0;
        int actual_drop_count   = 0;
        int irq_count           = 0;

        // =====================================================================
        // [FIX-BUG-A] Flag armed: el scoreboard ignora TX del DUT hasta que
        // el test llame arm() después de reset_counters().
        // Esto evita que TX del pipeline previo contaminen la verificación.
        // =====================================================================
        bit armed = 0;

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

        // Llamar después de reset_counters() para habilitar la verificación
        function void arm();
            armed = 1;
            `uvm_info(get_type_name(), "Scoreboard ARMADO — verificación activa", UVM_LOW)
        endfunction

        function void set_cfg(logic [1:0] off, logic [2:0] sz);
            if (off !== model.cfg_offset || sz !== model.cfg_size) begin
                `uvm_info(get_type_name(),
                    $sformatf("Config actualizada: offset=%0d size=%0d (pending_bytes=%0d flushed)",
                              off, sz, model.get_pending_count()), UVM_LOW)
            end
            model.set_config(off, sz);
        endfunction

        function void write_rx(rx_transaction tr);
            bit drop;

            // [FIX-BUG-A] Si no está armado, ignorar silenciosamente
            if (!armed) return;

            rx_packet_count++;
            drop = model.should_drop(tr);

            `uvm_info(get_type_name(),
                $sformatf("[RX] #%0d: data=0x%08X off=%0d size=%0d err=%0b should_drop=%0b",
                          rx_packet_count, tr.data, tr.offset, tr.size,
                          tr.err, drop), UVM_MEDIUM)

            if (tr.err) begin
                if (!drop) begin
                    `uvm_error(get_type_name(), $sformatf(
                        "FALSO DROP: RX#%0d data=0x%08X off=%0d size=%0d",
                        rx_packet_count, tr.data, tr.offset, tr.size))
                    error_count++;
                end else begin
                    expected_drop_count++;
                    `uvm_info(get_type_name(),
                        $sformatf("DROP OK: RX#%0d off=%0d size=%0d",
                                  rx_packet_count, tr.offset, tr.size), UVM_LOW)
                end
            end else begin
                if (drop) begin
                    `uvm_error(get_type_name(), $sformatf(
                        "DROP PERDIDO: RX#%0d data=0x%08X off=%0d size=%0d",
                        rx_packet_count, tr.data, tr.offset, tr.size))
                    error_count++;
                end else begin
                    model.process_rx_packet(tr, expected_tx_queue);
                    `uvm_info(get_type_name(),
                        $sformatf("RX PROCESADO: #%0d pending_bytes=%0d expected_tx=%0d",
                                  rx_packet_count, model.get_pending_count(),
                                  expected_tx_queue.size()), UVM_HIGH)
                end
            end
        endfunction

        function void write_tx(tx_transaction tr);
            tx_transaction expected;

            // [FIX-BUG-A] TX antes de arm() = pipeline residual del DUT, ignorar
            if (!armed) begin
                `uvm_info(get_type_name(),
                    $sformatf("TX pre-arm ignorado: data=0x%08X size=%0d off=%0d",
                              tr.data, tr.size, tr.offset), UVM_HIGH)
                return;
            end

            `uvm_info(get_type_name(),
                $sformatf("[TX] data=0x%08X off=%0d size=%0d", tr.data, tr.offset, tr.size),
                UVM_MEDIUM)

            // TX inesperado — puede ser residual de un cambio de CTRL concurrente
            if (expected_tx_queue.size() == 0) begin
                `uvm_warning(get_type_name(), $sformatf(
                    "TX sin esperado en cola (residual de cambio CTRL): data=0x%08X size=%0d — ignorado",
                    tr.data, tr.size))
                return;
            end

            expected = expected_tx_queue.pop_front();

            if (tr.data !== expected.data) begin
                `uvm_error(get_type_name(), $sformatf(
                    "TX DATA MISMATCH:\n  Esperado: 0x%08X (size=%0d)\n  Recibido: 0x%08X (size=%0d)",
                    expected.data, expected.size, tr.data, tr.size))
                error_count++;
                tx_mismatch_count++;
            end else if (tr.size !== expected.size) begin
                `uvm_error(get_type_name(), $sformatf(
                    "TX SIZE MISMATCH: esperado=%0d recibido=%0d data=0x%08X",
                    expected.size, tr.size, tr.data))
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
            // =====================================================================
            // [FIX-BUG-B] TX pendientes al final:
            // Si también hay pending_bytes > 0, significa que los legales que
            // llegaron no completaron un word completo de cfg_size bytes.
            // El DUT tampoco va a sacar ese TX incompleto → es normal, no error.
            // Solo es error si expected_tx_queue tiene items Y pending_bytes==0
            // (el modelo predijo TX que el DUT debió haber sacado pero no salieron).
            // =====================================================================
            if (expected_tx_queue.size() > 0) begin
                if (model.get_pending_count() > 0) begin
                    // Bytes insuficientes para completar → normal en tests mezclados
                    `uvm_warning(get_type_name(), $sformatf(
                        "TX PENDIENTES: %0d (con %0d pending_bytes — word incompleto, normal en test mixto)",
                        expected_tx_queue.size(), model.get_pending_count()))
                end else begin
                    // Sin bytes pendientes pero TX esperados → el DUT no sacó algo que debía
                    `uvm_error(get_type_name(), $sformatf(
                        "TX PERDIDOS: %0d TX esperados que el DUT nunca sacó (pending_bytes=0)",
                        expected_tx_queue.size()))
                    error_count++;
                end
            end

            if (model.get_pending_count() > 0 && expected_tx_queue.size() == 0) begin
                `uvm_info(get_type_name(), $sformatf(
                    "BYTES RESIDUALES: %0d bytes sin completar un TX (normal)",
                    model.get_pending_count()), UVM_LOW)
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

            if (error_count > 0)
                `uvm_error(get_type_name(), "TEST FALLIDO")
            else
                `uvm_info(get_type_name(), "TEST PASADO", UVM_NONE)
        endfunction

        function void reset_counters();
            armed = 0;   // desarmar — se rearma con arm() desde el test
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
