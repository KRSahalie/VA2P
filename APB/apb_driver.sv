// apb_driver.sv
`ifndef APB_DRIVER_SV
`define APB_DRIVER_SV

class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)
    
    virtual apb_if vif;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "APB interface not found in config_db")
        end
    endfunction
    
    task run_phase(uvm_phase phase);
        // Inicializar señales
        vif.drv_cb.psel <= 0;
        vif.drv_cb.penable <= 0;
        vif.drv_cb.paddr <= 0;
        vif.drv_cb.pwdata <= 0;
        vif.drv_cb.pwrite <= 0;
        
        forever begin
            apb_transaction tx;
            seq_item_port.get_next_item(tx);
            drive_transaction(tx);
            seq_item_port.item_done();
        end
    endtask
    
    task drive_transaction(apb_transaction tx);
        int timeout;  // Declarar al inicio del task
        timeout = 1000;  // Asignar valor después
        
        // Fase 1: Setup
        @(posedge vif.pclk);
        vif.drv_cb.psel <= 1;
        vif.drv_cb.penable <= 0;
        vif.drv_cb.paddr <= tx.addr;
        vif.drv_cb.pwrite <= tx.write;
        if (tx.write) begin
            vif.drv_cb.pwdata <= tx.data;
        end
        
        @(posedge vif.pclk);
        
        // Fase 2: Enable
        vif.drv_cb.penable <= 1;
        
        @(posedge vif.pclk);
        
        // Fase 3: Esperar ready (con timeout)
        while(vif.pready === 1'b0 && timeout > 0) begin
            @(posedge vif.pclk);
            timeout = timeout - 1;
        end
        
        if (timeout == 0) begin
            `uvm_error(get_type_name(), $sformatf("APB transaction timeout at addr 0x%0h", tx.addr))
        end
        
        // Fase 4: Capturar respuesta
        if (!tx.write) begin
            tx.data = vif.prdata;
        end
        tx.slverr = vif.pslverr;
        
        // Fase 5: Finalizar
        vif.drv_cb.psel <= 0;
        vif.drv_cb.penable <= 0;
        
        // Reportar error si ocurrió
        if (tx.slverr) begin
            `uvm_warning(get_type_name(), $sformatf("APB %s at addr 0x%0h returned error (pslverr=1)", 
                          tx.write ? "WRITE" : "READ", tx.addr))
        end
        
        `uvm_info(get_type_name(), tx.convert2string(), UVM_HIGH)
    endtask
    
endclass

`endif