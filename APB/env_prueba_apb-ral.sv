// cfs_aligner_apb_env.sv 
`ifndef CFS_ALIGNER_APB_ENV_SV
`define CFS_ALIGNER_APB_ENV_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import cfs_aligner_ral_pkg::*;

class cfs_aligner_apb_env extends uvm_env;
    `uvm_component_utils(cfs_aligner_apb_env)
    
    apb_agent apb_agent_h;
    cfs_aligner_regs regmodel;
    reg_adapter adapter;
    uvm_reg_predictor #(apb_transaction) predictor;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        apb_agent_h = apb_agent::type_id::create("apb_agent_h", this);
        
        // Crear y construir el regmodel
        regmodel = cfs_aligner_regs::type_id::create("regmodel", this);
        regmodel.build();
        regmodel.reset();
        
        adapter = reg_adapter::type_id::create("adapter", this);
        predictor = uvm_reg_predictor #(apb_transaction)::type_id::create("predictor", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        regmodel.default_map.set_auto_predict(0);
        regmodel.default_map.set_check_on_read(1);  
        
        // Conectar el predictor al monitor
        predictor.map = regmodel.default_map;
        predictor.adapter = adapter;
        apb_agent_h.monitor.ap.connect(predictor.bus_in);
        
        // Conectar el sequencer al adapter
        regmodel.default_map.set_sequencer(apb_agent_h.sequencer, adapter);
        
        // LOCK el modelo después de configurar
        regmodel.lock_model();  
        
        `uvm_info(get_type_name(), "RAL connected to APB agent", UVM_LOW)
    endfunction
    
    function void start_of_simulation_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "Environment simulation started", UVM_LOW)
        regmodel.print();
    endfunction
    
endclass

`endif