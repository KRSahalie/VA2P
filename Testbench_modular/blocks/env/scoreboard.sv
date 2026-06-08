// =============================================================================
// scoreboard.sv
// Scoreboard del testbench cfs_aligner
//
// Responsabilidades:
//   · write_rx : recibe cada transacción RX aceptada y decide si es drop
//                usando la fórmula (4 + rx.offset) % rx.size == 0
//   · write_tx : compara cada dato TX contra el esperado (bytes realineados)
//   · write_irq: lleva cuenta de IRQs detectadas
//   · set_actual_drops : compara CNT_DROP leído del DUT contra los esperados
//   · verify_irq_count : verifica mínimo de IRQs esperadas
//   · check_phase      : reporte final y fallo si hay errores
//
// [FIX-W1] El test lee el registro STATUS completo y extrae CNT_DROP[7:0]
//          con máscara antes de llamar set_actual_drops() — no usa field.read()
// =============================================================================

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp_rx  #(rx_transaction,  scoreboard) rx_export;
    uvm_analysis_imp_tx  #(tx_transaction,  scoreboard) tx_export;
    uvm_analysis_imp_irq #(irq_transaction, scoreboard) irq_export;

    rx_transaction rx_queue[$];

    int unsigned expected_drops;
    int unsigned actual_drops;
    int unsigned tx_count;
    int unsigned drop_count;
    int unsigned error_count;
    int unsigned irq_count;

    // Configuración de alineación — debe setearse desde el test antes del tráfico
    logic [1:0] cfg_offset;
    logic [2:0] cfg_size;

    localparam int ALGN_DATA_WIDTH = 32;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cfg_offset = 2'b00;
        cfg_size   = 3'd4;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        rx_export  = new("rx_export",  this);
        tx_export  = new("tx_export",  this);
        irq_export = new("irq_export", this);
    endfunction

    // Llamar desde el test antes de enviar tráfico
    function void set_cfg(logic [1:0] off, logic [2:0] sz);
        cfg_offset = off;
        cfg_size   = sz;
    endfunction

    function void write_rx(rx_transaction tr);
        int unsigned n_bytes   = tr.size;
        int unsigned resultado = ((ALGN_DATA_WIDTH/8) + tr.offset) % n_bytes;
        bit is_drop = (resultado != 0);

        `uvm_info("SB", $sformatf(
            "[RX] data=0x%08X off=%0d size=%0d formula=(%0d+%0d)%%%0d=%0d drop=%0b",
            tr.data, tr.offset, tr.size, ALGN_DATA_WIDTH/8,
            tr.offset, n_bytes, resultado, is_drop), UVM_MEDIUM)

        if (is_drop) begin
            expected_drops++;
            drop_count++;
            `uvm_info("SB", $sformatf("[DROP esperado #%0d]", expected_drops), UVM_LOW)
        end else begin
            rx_transaction exp = rx_transaction::type_id::create("exp");
            exp.copy(tr);
            rx_queue.push_back(exp);
        end
    endfunction

    function void write_tx(tx_transaction tr);
        rx_transaction expected_rx;
        logic [31:0]   expected_data;

        if (tr.offset !== 2'b00) begin
            `uvm_error("SB", $sformatf("[TX ERROR] offset=%0d != 0", tr.offset))
            error_count++; return;
        end
        if (rx_queue.size() == 0) begin
            `uvm_error("SB", $sformatf("[TX ERROR] dato inesperado 0x%08X", tr.data))
            error_count++; return;
        end

        expected_rx   = rx_queue.pop_front();
        expected_data = calc_expected_tx_data(expected_rx);

        if (tr.data !== expected_data) begin
            `uvm_error("SB", $sformatf(
                "[TX ERROR] esperado=0x%08X recibido=0x%08X (rx_off=%0d rx_size=%0d cfg_off=%0d cfg_sz=%0d)",
                expected_data, tr.data,
                expected_rx.offset, expected_rx.size,
                cfg_offset, cfg_size))
            error_count++;
        end else begin
            `uvm_info("SB", $sformatf("[TX OK] 0x%08X", tr.data), UVM_MEDIUM)
            tx_count++;
        end
    endfunction

    function void write_irq(irq_transaction tr);
        irq_count++;
        `uvm_info("SB", $sformatf("[IRQ #%0d] @ %0t", irq_count, tr.timestamp), UVM_LOW)
    endfunction

    function void set_actual_drops(int unsigned drops);
        actual_drops = drops;
        if (actual_drops !== expected_drops)
            `uvm_error("SB", $sformatf("[CNT_DROP ERROR] esperado=%0d leído=%0d",
                        expected_drops, actual_drops))
        else
            `uvm_info("SB", $sformatf("[CNT_DROP OK] %0d", actual_drops), UVM_LOW)
    endfunction

    function void verify_irq_count(int unsigned expected);
        if (irq_count < expected)
            `uvm_error("SB", $sformatf("[IRQ ERROR] esperados>=%0d recibidos=%0d",
                        expected, irq_count))
        else
            `uvm_info("SB", $sformatf("[IRQ OK] count=%0d", irq_count), UVM_LOW)
    endfunction

    function void check_phase(uvm_phase phase);
        if (rx_queue.size() > 0) begin
            `uvm_error("SB", $sformatf("[FINAL] %0d RX sin TX correspondiente",
                        rx_queue.size()))
            error_count++;
        end
        `uvm_info("SB", $sformatf(
            "\n==========================================\n  TX OK:%0d  Drops:%0d  IRQs:%0d  Errores:%0d\n==========================================",
            tx_count, drop_count, irq_count, error_count), UVM_NONE)
        if (error_count > 0) `uvm_error("SB", "TEST FALLIDO")
        else                  `uvm_info("SB",  "TEST PASADO", UVM_NONE)
    endfunction

    // Extrae cfg_size bytes desde rx.data empezando en rx.offset
    // y los coloca en los bytes bajos del resultado (offset=0 en TX)
    function logic [31:0] calc_expected_tx_data(rx_transaction rx);
        logic [31:0] result = 32'h0;
        for (int i = 0; i < int'(cfg_size); i++) begin
            logic [7:0] bval;
            int src_byte = int'(rx.offset) + i;
            if (src_byte < 4)
                bval = rx.data[src_byte*8 +: 8];
            else
                bval = 8'h0;
            result[i*8 +: 8] = bval;
        end
        return result;
    endfunction

    function void reset_counters();
        rx_queue.delete();
        expected_drops = 0;
        actual_drops   = 0;
        tx_count       = 0;
        drop_count     = 0;
        error_count    = 0;
        irq_count      = 0;
    endfunction

endclass : scoreboard
