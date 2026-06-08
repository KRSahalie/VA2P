//apb_monitor.sv
`ifndef APB_MONITOR_SV
`define APB_MONITOR_SV

class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    
    virtual apb_if vif;
    uvm_analysis_port #(apb_transaction) ap;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "APB interface not found in config_db")
        end
    endfunction
    
    task run_phase(uvm_phase phase);
        forever begin
            apb_transaction tx = apb_transaction::type_id::create("tx");
            
            // Esperar inicio de transacción
            @(posedge vif.pclk);
            while(vif.psel === 1'b0) begin
                @(posedge vif.pclk);
            end
            
            // Capturar setup
            tx.addr = vif.paddr;
            tx.write = vif.pwrite;
            if (tx.write) tx.data = vif.pwdata;
            
            // Esperar enable
            while(vif.penable === 1'b0) begin
                @(posedge vif.pclk);
            end
            
            // Esperar ready
            while(vif.pready === 1'b0) begin
                @(posedge vif.pclk);
            end
            
            // Capturar lectura
            if (!tx.write) tx.data = vif.prdata;
            tx.slverr = vif.pslverr;
            
            ap.write(tx);
            `uvm_info(get_type_name(), tx.convert2string(), UVM_HIGH)
        end
    endtask
    
endclass

`endif