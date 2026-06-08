// aligner_env.sv
`ifndef ALIGNER_ENV_SV
`define ALIGNER_ENV_SV

package aligner_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import apb_components_pkg::*;
    import md_components_pkg::*;
    import aligner_tb_pkg::*;
    import scoreboard_pkg::*;
    import cfs_aligner_ral_pkg::*;

    class aligner_env extends uvm_env;
        `uvm_component_utils(aligner_env)

        // APB
        apb_agent   apb_agt;
        
        // MD
        rx_agent    rx_agt;
        tx_monitor  tx_mon;
        tx_ready_driver tx_rdy_drv;
        irq_monitor irq_mon;
        
        // Scoreboard
        scoreboard  sb;
        
        // RAL
        cfs_aligner_regs reg_model;
        
        // Adapter y Predictor
        apb_reg_adapter adapter;
        uvm_reg_predictor #(apb_transaction) predictor;  

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            
            apb_agt = apb_agent::type_id::create("apb_agt", this);
            rx_agt  = rx_agent::type_id::create("rx_agt", this);
            tx_mon  = tx_monitor::type_id::create("tx_mon", this);
            tx_rdy_drv = tx_ready_driver::type_id::create("tx_rdy_drv", this);
            irq_mon = irq_monitor::type_id::create("irq_mon", this);
            sb      = scoreboard::type_id::create("sb", this);
            
            if (!uvm_config_db #(cfs_aligner_regs)::get(this, "", "reg_model", reg_model))
                `uvm_fatal("ENV", "No se encontró reg_model")
            
            adapter = apb_reg_adapter::type_id::create("adapter", this);
            
        
            predictor = uvm_reg_predictor #(apb_transaction)::type_id::create("predictor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            
            rx_agt.ap.connect(sb.rx_export);
            tx_mon.ap.connect(sb.tx_export);
            irq_mon.ap.connect(sb.irq_export);
            
            reg_model.default_map.set_sequencer(apb_agt.sequencer, adapter);
            reg_model.default_map.set_auto_predict(0);
            
            //CONFIGURAR EL PREDICTOR 
            predictor.map = reg_model.default_map;
            predictor.adapter = adapter;
            apb_agt.monitor.ap.connect(predictor.bus_in);
            reg_model.lock_model();
            `uvm_info(get_type_name(), "Environment connected", UVM_LOW)
        endfunction
        
        function void start_of_simulation_phase(uvm_phase phase);
            `uvm_info(get_type_name(), "Simulation started", UVM_LOW)
            reg_model.print();
          
        endfunction
        
        function void set_sb_config(logic [1:0] offset, logic [2:0] size);
            sb.set_cfg(offset, size);
        endfunction
        
        function void verify_drops(int unsigned drops);
            sb.set_actual_drops(drops);
        endfunction

    endclass : aligner_env

endpackage : aligner_env_pkg

`endif // ALIGNER_ENV_SV