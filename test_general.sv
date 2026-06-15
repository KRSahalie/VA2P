// test_general.sv
`ifndef TEST_GENERAL_SV
`define TEST_GENERAL_SV

import uvm_pkg::*;
import apb_components_pkg::*;
import md_components_pkg::*;
import aligner_tb_pkg::*;
import scoreboard_pkg::*;
import aligner_env_pkg::*;
import md_sequences_pkg::*;
import cfs_aligner_ral_pkg::*;

class test_general extends uvm_test;
    `uvm_component_utils(test_general)

    aligner_env env;

    int    semilla;
    string test_mode;
    int    apb_num_trans;
    int    md_num_pkts;
    int    md_peso_legal;
    int    ctrl_size;
    int    ctrl_offset;
    string md_patron;
    int    timeout_ms;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        set_defaults();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = aligner_env::type_id::create("env", this);
    endfunction

    function void set_defaults();
        semilla       = 1;
        test_mode     = "FULL";
        apb_num_trans = 100;
        md_num_pkts   = 50;
        md_peso_legal = 80;
        ctrl_size     = 2;
        ctrl_offset   = 0;
        md_patron     = "RANDOM";
        timeout_ms    = 100;
    endfunction

    function void leer_plusargs();
        $value$plusargs("SEMILLA=%d",       semilla);
        $value$plusargs("TEST_MODE=%s",     test_mode);
        $value$plusargs("APB_NUM_TRANS=%d", apb_num_trans);
        $value$plusargs("MD_NUM_PKTS=%d",   md_num_pkts);
        $value$plusargs("MD_PESO_LEGAL=%d", md_peso_legal);
        $value$plusargs("CTRL_SIZE=%d",     ctrl_size);
        $value$plusargs("CTRL_OFFSET=%d",   ctrl_offset);
        $value$plusargs("MD_PATRON=%s",     md_patron);
        $value$plusargs("TIMEOUT_MS=%d",    timeout_ms);

        if (ctrl_size     < 1)   ctrl_size     = 1;
        if (ctrl_size     > 4)   ctrl_size     = 4;
        if (ctrl_offset   < 0)   ctrl_offset   = 0;
        if (ctrl_offset   > 3)   ctrl_offset   = 3;
        if (apb_num_trans < 1)   apb_num_trans = 1;
        if (md_num_pkts   < 1)   md_num_pkts   = 1;
        if (md_peso_legal < 0)   md_peso_legal = 0;
        if (md_peso_legal > 100) md_peso_legal = 100;
        if (timeout_ms    < 10)  timeout_ms    = 10;

        $srandom(semilla);
    endfunction

    function bit is_valid_ctrl(int size, int offset);
        if (size == 0) return 0;
        return ((4 + offset) % size) == 0;
    endfunction

    function void get_valid_ctrl_combinations(ref int sizes[$], ref int offsets[$]);
        for (int s = 1; s <= 4; s++)
            for (int o = 0; o < 4; o++)
                if (is_valid_ctrl(s, o)) begin
                    sizes.push_back(s);
                    offsets.push_back(o);
                end
    endfunction

    task configurar_ctrl();
        uvm_status_e status;
        int valid_sizes[$], valid_offsets[$];
        int idx;

        if (ctrl_size == -1) begin
            get_valid_ctrl_combinations(valid_sizes, valid_offsets);
            idx         = $urandom_range(valid_sizes.size() - 1);
            ctrl_size   = valid_sizes[idx];
            ctrl_offset = valid_offsets[idx];
        end

        if (!is_valid_ctrl(ctrl_size, ctrl_offset)) begin
            `uvm_warning(get_type_name(), $sformatf(
                "Combinación inválida size=%0d offset=%0d, usando default (1,0)",
                ctrl_size, ctrl_offset))
            ctrl_size   = 1;
            ctrl_offset = 0;
        end

        env.reg_model.ctrl.size.set(ctrl_size);
        env.reg_model.ctrl.offset.set(ctrl_offset);
        env.reg_model.ctrl.update(status);

        if (status != UVM_IS_OK)
            `uvm_error(get_type_name(), "Fallo al configurar CTRL")

        env.set_sb_config(ctrl_offset, ctrl_size);

        `uvm_info(get_type_name(),
            $sformatf("CTRL configurado: size=%0d offset=%0d", ctrl_size, ctrl_offset),
            UVM_LOW)
    endtask

    task configurar_irqen();
        uvm_status_e status;
        env.reg_model.irqen.rx_fifo_empty.set(1);
        env.reg_model.irqen.rx_fifo_full.set(1);
        env.reg_model.irqen.tx_fifo_empty.set(1);
        env.reg_model.irqen.tx_fifo_full.set(1);
        env.reg_model.irqen.max_drop.set(1);
        env.reg_model.irqen.update(status);
        `uvm_info(get_type_name(), "IRQEN configurado (todas las interrupciones habilitadas)", UVM_LOW)
    endtask

    // =========================================================================
    // [FIX-BUG-A] drain_dut_pipeline: espera a que el DUT vacíe sus FIFOs
    // antes de armar el scoreboard. Así los TX residuales del reset no
    // llegan al scoreboard armado.
    // =========================================================================
    task drain_dut_pipeline();
        uvm_status_e   status;
        uvm_reg_data_t rd_data;
        int max_wait = 1000;

        `uvm_info(get_type_name(), "Drenando pipeline del DUT...", UVM_LOW)
        while (max_wait > 0) begin
            env.reg_model.status.read(status, rd_data);
            if (rd_data[19:8] == 12'h0) break;  // rx_lvl[11:8] + tx_lvl[19:16] == 0
            #100;
            max_wait--;
        end
        if (max_wait == 0)
            `uvm_warning(get_type_name(), "Timeout drenando pipeline — FIFOs no vaciaron")
        else
            `uvm_info(get_type_name(), "Pipeline drenado OK", UVM_LOW)
    endtask

    task test_apb();
        uvm_status_e   status;
        uvm_reg_data_t rd_data;
        int illegal_writes    = 0;
        int successful_writes = 0;
        int op, reg_sel, idx;
        int valid_sizes[$], valid_offsets[$];
        int new_size, new_offset;

        `uvm_info(get_type_name(),
            $sformatf("Iniciando %0d transacciones APB", apb_num_trans), UVM_LOW)

        for (int i = 0; i < apb_num_trans; i++) begin
            op = $urandom_range(0, 9);

            case(op)
                0,1,2,3: begin
                    reg_sel = $urandom_range(0, 3);
                    case(reg_sel)
                        0: env.reg_model.ctrl.read(status, rd_data);
                        1: env.reg_model.status.read(status, rd_data);
                        2: env.reg_model.irqen.read(status, rd_data);
                        3: env.reg_model.irq.read(status, rd_data);
                    endcase
                end
                4,5: begin
                    valid_sizes.delete();
                    valid_offsets.delete();
                    get_valid_ctrl_combinations(valid_sizes, valid_offsets);
                    if (valid_sizes.size() > 0) begin
                        idx        = $urandom_range(valid_sizes.size() - 1);
                        new_size   = valid_sizes[idx];
                        new_offset = valid_offsets[idx];

                        env.reg_model.ctrl.size.set(new_size);
                        env.reg_model.ctrl.offset.set(new_offset);
                        env.reg_model.ctrl.update(status);

                        // [FIX-BUG2] Solo actualizar scoreboard si DUT aceptó
                        if (status == UVM_IS_OK && is_valid_ctrl(new_size, new_offset)) begin
                            // Esperar que el DUT drene TX FIFO antes de cambiar config del scoreboard.
                            // Sin esto, el scoreboard hace flush de expected_tx_queue mientras el DUT
                            // todavía tiene TXs en vuelo con la config anterior → DATA MISMATCH falso.
                            begin
                                uvm_status_e   drain_status;
                                uvm_reg_data_t rd;
                                int wait_cycles = 500;
                                do begin
                                    #100;
                                    env.reg_model.status.read(drain_status, rd);
                                    wait_cycles--;
                                end while (rd[19:16] != 4'h0 && wait_cycles > 0);
                                if (wait_cycles == 0)
                                    `uvm_warning(get_type_name(), "Timeout drenando TX FIFO antes de cambio de CTRL")
                            end
                            env.set_sb_config(new_offset, new_size);
                            ctrl_size   = new_size;
                            ctrl_offset = new_offset;
                            successful_writes++;
                        end else begin
                            `uvm_warning(get_type_name(), $sformatf(
                                "CTRL write rechazado por DUT: size=%0d offset=%0d — sb NO actualizado",
                                new_size, new_offset))
                        end
                    end
                end
                6: begin
                    // Escritura inválida — no actualizar scoreboard
                    env.reg_model.ctrl.size.set(0);
                    env.reg_model.ctrl.offset.set($urandom_range(0, 3));
                    env.reg_model.ctrl.update(status);
                    if (status == UVM_NOT_OK) illegal_writes++;
                end
                7,8: begin
                    env.reg_model.irqen.rx_fifo_empty.set($urandom_range(0, 1));
                    env.reg_model.irqen.update(status);
                end
                9: begin
                    env.reg_model.irq.write(status, 'h1F);
                end
            endcase

            #($urandom_range(1, 10));
        end

        `uvm_info(get_type_name(), $sformatf(
            "APB test completado: exitosas=%0d ilegales=%0d",
            successful_writes, illegal_writes), UVM_LOW)
    endtask

    function logic [31:0] generar_dato(int idx);
        case(md_patron)
            "INCR":  return idx;
            "DECR":  return (md_num_pkts - idx);
            "FIXED": return 32'hA5A5A5A5;
            "ZEROS": return 32'h00000000;
            "ONES":  return 32'hFFFFFFFF;
            default: return $urandom();
        endcase
    endfunction

    task test_md();
        rx_mixed_seq rx_seq;
        int n_legal, n_illegal;
        int max_cycles;

        n_legal   = (md_num_pkts * md_peso_legal) / 100;
        n_illegal = md_num_pkts - n_legal;

        `uvm_info(get_type_name(), $sformatf(
            "Iniciando MD: %0d legales, %0d ilegales, patrón=%s",
            n_legal, n_illegal, md_patron), UVM_LOW)

        rx_seq           = rx_mixed_seq::type_id::create("rx_seq");
        rx_seq.n_legal   = n_legal;
        rx_seq.n_illegal = n_illegal;
        rx_seq.patron    = md_patron;
        rx_seq.start(env.rx_agt.sequencer);

        // =====================================================================
        // [FIX-BUG-B] Esperar a que el DUT drene sus FIFOs (tx_lvl=0, rx_lvl=0)
        // además de que el modelo no tenga TX pendientes.
        // Si pending_bytes > 0 al final, es normal — no alcanzaron cfg_size bytes.
        // =====================================================================
        max_cycles = timeout_ms * 10_000;
        begin
            uvm_status_e   status;
            uvm_reg_data_t rd_data;
            bit dut_empty;

            while (max_cycles > 0) begin
                env.reg_model.status.read(status, rd_data);
                dut_empty = (rd_data[19:8] == 12'h0);  // rx_lvl + tx_lvl = 0

                // Terminamos cuando:
                //  a) DUT FIFOs vacíos, Y
                //  b) modelo no tiene TX esperados pendientes, O
                //     si tiene pending_bytes > 0 (word incompleto — nunca saldra TX)
                if (dut_empty &&
                    (env.sb.expected_tx_queue.size() == 0 ||
                     env.sb.model.get_pending_count() > 0))
                    break;

                #100;
                max_cycles--;
            end
        end

        if (max_cycles == 0)
            `uvm_warning(get_type_name(), $sformatf(
                "Timeout: pending_bytes=%0d, expected_tx=%0d",
                env.sb.model.get_pending_count(),
                env.sb.expected_tx_queue.size()))

        `uvm_info(get_type_name(), "MD test completado", UVM_LOW)
    endtask

    task verificar();
        uvm_status_e   status;
        uvm_reg_data_t rd_data;

        env.reg_model.status.read(status, rd_data);
        env.verify_drops(env.reg_model.status.cnt_drop.get_mirrored_value());

        `uvm_info(get_type_name(), $sformatf(
            "STATUS final: cnt_drop=%0d, rx_lvl=%0d, tx_lvl=%0d",
            env.reg_model.status.cnt_drop.get_mirrored_value(),
            env.reg_model.status.rx_lvl.get_mirrored_value(),
            env.reg_model.status.tx_lvl.get_mirrored_value()), UVM_LOW)

        env.sb.print_model_status();
    endtask

    function void imprimir_configuracion();
        `uvm_info(get_type_name(), $sformatf(
            "\n==================================================\n  TEST GENERAL CONFIGURATION\n==================================================\n  SEMILLA            = %0d\n  TEST_MODE          = %s\n  APB_NUM_TRANS      = %0d\n  MD_NUM_PKTS        = %0d\n  MD_PESO_LEGAL      = %0d%%\n  CTRL_SIZE          = %0d\n  CTRL_OFFSET        = %0d\n  MD_PATRON          = %s\n  TIMEOUT_MS         = %0d\n==================================================",
            semilla, test_mode, apb_num_trans, md_num_pkts,
            md_peso_legal, ctrl_size, ctrl_offset, md_patron, timeout_ms), UVM_LOW)
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        leer_plusargs();
        imprimir_configuracion();

        // Esperar reset HW
        #200;

        configurar_ctrl();
        configurar_irqen();

        // =====================================================================
        // [FIX-BUG-A] Secuencia de arranque limpio:
        //   1. reset_counters() — desarma el scoreboard
        //   2. drain_dut_pipeline() — espera que FIFOs del DUT estén vacíos
        //   3. arm() — arma el scoreboard, ahora sí se verifican TX/RX
        // Así cualquier TX residual del DUT antes del test no genera errores.
        // =====================================================================
        env.sb.reset_counters();
        drain_dut_pipeline();
        env.sb.arm();

        case(test_mode)
            "APB_ONLY": begin
                test_apb();
                #500;
            end
            "MD_ONLY": begin
                test_md();
            end
            "FULL": begin
                fork
                    test_apb();
                    begin
                        #500;
                        test_md();
                    end
                join
            end
            default:
                `uvm_error(get_type_name(), $sformatf("Modo desconocido: %s", test_mode))
        endcase

        #2000;
        verificar();

        phase.drop_objection(this);
    endtask

endclass : test_general

`endif // TEST_GENERAL_SV
