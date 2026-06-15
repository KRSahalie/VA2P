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
                if (src_byte_idx < BYTES_PER_WORD) begin
                    pending_bytes.push_back(rx_bytes[src_byte_idx]);
                end
            end
            rx_packets_consumed++;

            while (pending_bytes.size() >= (int'(cfg_offset) + int'(cfg_size))) begin
                tx_transaction tx;
                logic [31:0] word_data = 32'h0;
                
                tx = tx_transaction::type_id::create("tx_expected");
                tx.offset = cfg_offset;
                tx.size   = cfg_size;
                tx.valid  = 1'b1;
                tx.err    = 1'b0;

                for (int i = 0; i < int'(cfg_offset); i++) begin
                    word_data[i*8 +: 8] = 8'h0;
                end

                for (int i = 0; i < int'(cfg_size); i++) begin
                    logic [7:0] b = pending_bytes.pop_front();
                    word_data[(int'(cfg_offset) + i)*8 +: 8] = b;
                end

                for (int i = int'(cfg_offset) + int'(cfg_size); i < BYTES_PER_WORD; i++) begin
                    word_data[i*8 +: 8] = 8'h0;
                end

                tx.data = word_data;
                tx_queue.push_back(tx);
                tx_packets_generated++;
            end
        endfunction

        function int get_pending_count();
            return pending_bytes.size();
        endfunction

        function void reset();
            pending_bytes.delete();
            tx_packets_generated = 0;
            rx_packets_consumed  = 0;
        endfunction
    endclass : ref_model


    class scoreboard extends uvm_scoreboard;
        `uvm_component_utils(scoreboard)

        uvm_analysis_imp_rx #(rx_transaction, scoreboard) rx_export;
        uvm_analysis_imp_tx #(tx_transaction, scoreboard) tx_export;
        uvm_analysis_imp_irq#(irq_transaction, scoreboard) irq_export;

        ref_model model;
        tx_transaction expected_tx_queue[$];

        bit armed = 0;

        int expected_drop_count = 0;
        int actual_drop_count   = 0;
        int rx_packet_count     = 0;
        int tx_match_count      = 0;
        int tx_mismatch_count   = 0;
        int error_count         = 0;
        int irq_count           = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            model = new();
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            rx_export  = new("rx_export", this);
            tx_export  = new("tx_export", this);
            irq_export = new("irq_export", this);
        endfunction

        function void arm();
            this.armed = 1;
            `uvm_info(get_type_name(), "Scoreboard ARMED. Iniciando verificaciones.", UVM_LOW)
        endfunction

        function void set_cfg(logic [1:0] off, logic [2:0] sz);
            string msg_str;
            if (off !== model.cfg_offset || sz !== model.cfg_size) begin
                msg_str = $sformatf("Cambio dinamico detectado en CTRL -> Viejo(OFF=%0d, SZ=%0d) -> Nuevo(OFF=%0d, SZ=%0d). Forzando Flush.", 
                    model.cfg_offset, model.cfg_size, off, sz);
                `uvm_info(get_type_name(), msg_str, UVM_MEDIUM)
                
                expected_tx_queue.delete();
                model.pending_bytes.delete(); 
            end
            model.set_config(off, sz);
        endfunction

        virtual function void write_rx(rx_transaction rx);
            string msg_str;
            if (!armed) return;

            rx_packet_count++;
            if (rx.err) begin
                expected_drop_count++;
                msg_str = $sformatf("RX Packet detectado con ERR=1 (Drop Esperado #%0d)", expected_drop_count);
                `uvm_info(get_type_name(), msg_str, UVM_HIGH)
            end else begin
                model.process_rx_packet(rx, expected_tx_queue);
            end
        end function

        virtual function void write_tx(tx_transaction tx);
            tx_transaction exp_tx;
            string msg_str;

            if (!armed) return;

            if (expected_tx_queue.size() == 0) begin
                msg_str = $sformatf("Paquete TX recibido inesperado. No hay transacciones esperadas en la cola. Recibido: %s", tx.convert2string());
                `uvm_error(get_type_name(), msg_str)
                error_count++;
                tx_mismatch_count++;
                return;
            end

            exp_tx = expected_tx_queue.pop_front();

            if (tx.do_compare(exp_tx, null)) begin
                tx_match_count++;
                msg_str = $sformatf("MATCH exitoso (TX #%0d): %s", tx_match_count, tx.convert2string());
                `uvm_info(get_type_name(), msg_str, UVM_HIGH)
            end else begin
                tx_mismatch_count++;
                error_count++;
                msg_str = $sformatf("MISMATCH en TX #%0d\nESPERADO: %s\nRECIBIDO: %s", 
                    (tx_match_count + tx_mismatch_count), exp_tx.convert2string(), tx.convert2string());
                `uvm_error(get_type_name(), msg_str)
            end
        endfunction

        virtual function void write_irq(irq_transaction irq);
            string msg_str;
            if (!armed) return;
            if (irq.irq_detected) begin
                irq_count++;
                msg_str = $sformatf("Evento IRQ detectado en interfaz fisico (Total: %0d)", irq_count);
                `uvm_info(get_type_name(), msg_str, UVM_HIGH)
            end
        endfunction

        function void report_phase(uvm_phase phase);
            string reporte_str;
            string warn_str;
            string info_str;
            super.report_phase(phase);
            
            if (expected_tx_queue.size() > 0) begin
                warn_str = $sformatf("PAQUETES FALTANTES: Quedaron %0d transacciones sin recibir en expected_tx_queue al terminar.", expected_tx_queue.size());
                `uvm_warning(get_type_name(), warn_str)
                error_count += expected_tx_queue.size();
            end

            if (model.get_pending_count() > 0) begin
                info_str = $sformatf("BYTES PENDIENTES EN MODELO: %0d (puede ser normal si el test termino abruptamente)", model.get_pending_count());
                `uvm_info(get_type_name(), info_str, UVM_MEDIUM)
            end

            reporte_str = $sformatf("\n==========================================\n  RESUMEN SCOREBOARD\n==========================================\n  RX packets recibidos:   %0d\n  Drops esperados:        %0d\n  Drops reales (CNT_DROP):%0d\n  TX generados (modelo):  %0d\n  TX recibidos (fisicos): %0d\n  TX correctos:           %0d\n  TX incorrectos:         %0d\n  IRQs recibidas:         %0d\n  Errores totales:        %0d\n==========================================",
                rx_packet_count,
                expected_drop_count,
                actual_drop_count,
                model.tx_packets_generated,
                (tx_match_count + tx_mismatch_count),
                tx_match_count,
                tx_mismatch_count,
                irq_count,
                error_count);

            `uvm_info(get_type_name(), reporte_str, UVM_NONE)

            if (error_count > 0)
                `uvm_error(get_type_name(), "TEST FALLIDO")
            else
                `uvm_info(get_type_name(), "TEST PASADO", UVM_NONE)
        endfunction

        function void reset_counters();
            armed = 0;   
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
            string msg_str;
            msg_str = $sformatf("MODEL STATUS: pending_bytes=%0d, tx_generated=%0d, rx_consumed=%0d",
                model.get_pending_count(), model.tx_packets_generated, model.rx_packets_consumed);
            `uvm_info(get_type_name(), msg_str, UVM_LOW)
        endfunction

    endclass : scoreboard
endpackage : scoreboard_pkg
`endif // SCOREBOARD_SV
