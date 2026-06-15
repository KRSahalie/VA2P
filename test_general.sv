// test_general.sv
`ifndef TEST_GENERAL_SV
`define TEST_GENERAL_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
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
        timeout_ms    = 50;
    endfunction

    function void leer_plusargs();
        if ($value$plusargs("SEMILLA=%d", semilla))          srandom(semilla);
        if (!$value$plusargs("TEST_MODE=%s", test_mode))       test_mode = "FULL";
        if (!$value$plusargs("APB_NUM_TRANS=%d", apb_num_trans)) apb_num_trans = 100;
        if (!$value$plusargs("MD_NUM_PKTS=%d", md_num_pkts))   md_num_pkts = 50;
        if (!$value$plusargs("MD_PESO_LEGAL=%d", md_peso_legal)) md_peso_legal = 80;
        if (!$value$plusargs("CTRL_SIZE=%d", ctrl_size))       ctrl_size = 2;
        if (!$value$plusargs("CTRL_OFFSET=%d", ctrl_offset))   ctrl_offset = 0;
        if (!$value$plusargs("MD_PATRON=%s", md_patron))       md_patron = "RANDOM";
        if (!$value$plusargs("TIMEOUT_MS=%d", timeout_ms))     timeout_ms = 50;
    endfunction

    function void imprimir_configuracion();
        `uvm_info(get_type_name(), "==========================================", UVM_NONE)
        `uvm_info(get_type_name(), "  CONFIGURACION DEL TEST GENERAL", UVM_NONE)
        `uvm_info(get_type_name(), "==========================================", UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("  Semilla:         %0d", semilla), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("  Modo de Test:    %s", test_mode), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("  Transacciones APB:%0d", apb_num_trans), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("  Paquetes MD:     %0d", md_num_pkts), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("  Patron MD:       %s", md_patron), UVM_NONE)
        `uvm_info(get_type_name(), $sformatf("  Config Inicial:  OFFSET=%0d, SIZE=%0d", ctrl_offset, ctrl_size), UVM_NONE)
        `uvm_info(get_type_name(), "==========================================", UVM_NONE)
    endfunction

    task configurar_ctrl();
        uvm_status_e status;
        `uvm_info(get_type_name(), "Configurando registro CTRL inicial...", UVM_LOW)
        env.reg_model.ctrl.size.set(ctrl_size);
        env.reg_model.ctrl.offset.set(ctrl_offset);
        env.reg_model.ctrl.update(status);
        if (status != UVM_IS_OK)
            `uvm_error(get_type_name(), "Error al escribir registro CTRL inicial por APB")
        env.set_sb_config(ctrl_offset, ctrl_size);
    endtask

    task configurar_irqen();
        uvm_status_e status;
        `uvm_info(get_type_name(), "Configurando registro IRQEN inicial...", UVM_LOW)
        env.reg_model.irqen.write(status, 32'h0000_001F);
        if (status != UVM_IS_OK)
            `uvm_error(get_type_name(), "Error al escribir registro IRQEN por APB")
    endtask

    task drain_dut_pipeline();
        `uvm_info(get_type_name(), "Esperando vaciado del pipeline del DUT...", UVM_HIGH)
        #200;
    endtask

    task test_md();
        md_base_seq seq;
        `uvm_info(get_type_name(), "Iniciando generacion de trafico Memory Data (MD)...", UVM_LOW)

        if (md_patron == "ONES") begin
            md_ones_seq s = md_ones_seq::type_id::create("md_ones_seq");
            s.num_packets = md_num_pkts;
            seq = s;
        end else begin
            md_random_seq s = md_random_seq::type_id::create("md_random_seq");
            s.num_packets = md_num_pkts;
            s.peso_legal  = md_peso_legal;
            seq = s;
        end

        seq.start(env.rx_agt.sequencer);
        `uvm_info(get_type_name(), "Trafico MD completado.", UVM_LOW)
    endtask

    task test_apb();
        uvm_status_e status;
        logic [31:0] rd_data;
        int successful_writes = 0;

        `uvm_info(get_type_name(), $sformatf("Iniciando test_apb con apb_num_trans=%0d", apb_num_trans), UVM_LOW)

        for (int i = 0; i < apb_num_trans; i++) begin
            int op = $urandom_range(0, 2);

            case(op)
                0: begin 
                    logic [2:0] new_size;
                    logic [1:0] new_offset;
                    
                    do begin
                        new_size   = $urandom_range(1, 4);
                        new_offset = $urandom_range(0, 3);
                    end while (((4 + new_offset) % new_size) != 0);

                    `uvm_info(get_type_name(), $sformatf("[APB_REQ] Intentando cambiar a OFFSET=%0d, SIZE=%0d", new_offset, new_size), UVM_HIGH)
                    
                    env.reg_model.ctrl.size.set(new_size);
                    env.reg_model.ctrl.offset.set(new_offset);
                    env.reg_model.ctrl.update(status); 

                    if (status == UVM_IS_OK) begin
                        ctrl_size   = new_size;
                        ctrl_offset = new_offset;
                        
                        #40; 
                        
                        env.set_sb_config(new_offset, new_size);
                        successful_writes++;
                    end else begin
                        `uvm_error(get_type_name(), "Fallo la escritura APB en el registro CTRL")
                    end
                end

                1: begin 
                    env.reg_model.status.read(status, rd_data);
                    if (status == UVM_IS_OK) begin
                        `uvm_info(get_type_name(), $sformatf("[APB_READ] STATUS = 0x%0h (CNT_DROP=%0d, RX_LVL=%0d, TX_LVL=%0d)", 
                            rd_data, rd_data[7:0], rd_data[11:8], rd_data[19:16]), UVM_HIGH)
                    end
                end

                2: begin 
                    env.reg_model.irq.read(status, rd_data);
                    if (status == UVM_IS_OK && rd_data[4:0] != 0) begin
                        env.reg_model.irq.write(status, rd_data);
                        `uvm_info(get_type_name(), $sformatf("[APB_IRQ] Interrupciones limpiadas: 0x%0h", rd_data[4:0]), UVM_HIGH)
                    end
                end
            endcase
            
            #( $urandom_range(10, 100) );
        end

        `uvm_info(get_type_name(), $sformatf("test_apb finalizado. Cambios de configuracion exitosos: %0d", successful_writes), UVM_LOW)
    endtask

    function void verificar();
        uvm_status_e status;
        logic [31:0] final_status;
        int cnt_drop_real;

        env.reg_model.status.read(status, final_status);
        if (status == UVM_IS_OK) begin
            cnt_drop_real = final_status[7:0];
            env.verify_drops(cnt_drop_real);
        end else begin
            `uvm_error(get_type_name(), "No se pudo leer el registro STATUS para la verificacion final")
        end
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        leer_plusargs();
        imprimir_configuracion();

        #200; 

        configurar_ctrl();
        configurar_irqen();

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
