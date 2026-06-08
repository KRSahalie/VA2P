// apb_components.sv
`ifndef APB_COMPONENTS_SV
`define APB_COMPONENTS_SV

package apb_components_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    // =========================================================================
    // APB TRANSACTION
    // =========================================================================
    class apb_transaction extends uvm_sequence_item;
        `uvm_object_utils_begin(apb_transaction)
            `uvm_field_int(addr,   UVM_ALL_ON)
            `uvm_field_int(data,   UVM_ALL_ON)
            `uvm_field_int(write,  UVM_ALL_ON)
            `uvm_field_int(slverr, UVM_ALL_ON)
        `uvm_object_utils_end
        
        rand logic [15:0] addr;
        rand logic [31:0] data;
        rand bit write;
        
        bit slverr;
        
        constraint valid_addr {
            soft addr inside {
                16'h0000,   // CTRL
                16'h000C,   // STATUS  
                16'h00F0,   // IRQEN
                16'h00F4    // IRQ
            };
        }
        
        function new(string name = "apb_transaction");
            super.new(name);
        endfunction
        
        function string convert2string();
            string op = write ? "WRITE" : "READ ";
            return $sformatf("APB %s | addr=0x%04h | data=0x%08h | err=%0d",
                             op, addr, data, slverr);
        endfunction
        
        function void do_copy(uvm_object rhs);
            apb_transaction tx;
            $cast(tx, rhs);
            addr = tx.addr;
            data = tx.data;
            write = tx.write;
            slverr = tx.slverr;
        endfunction
        
        function void do_print(uvm_printer printer);
            printer.print_string("apb_transaction", convert2string());
        endfunction
    endclass : apb_transaction

    // =========================================================================
    // APB SEQUENCER
    // =========================================================================
    class apb_sequencer extends uvm_sequencer #(apb_transaction);
        `uvm_component_utils(apb_sequencer)
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass : apb_sequencer

    // =========================================================================
    // APB DRIVER 
    // =========================================================================
    class apb_driver extends uvm_driver #(apb_transaction);
        `uvm_component_utils(apb_driver)
        
        virtual aligner_if vif;  
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db#(virtual aligner_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(), "APB interface (aligner_if) not found in config_db")
            end
        endfunction
        
        task run_phase(uvm_phase phase);
            // Inicializar señales APB
            vif.psel <= 0;
            vif.penable <= 0;
            vif.paddr <= 0;
            vif.pwdata <= 0;
            vif.pwrite <= 0;
            
            @(posedge vif.clk);
            
            forever begin
                apb_transaction tx;
                seq_item_port.get_next_item(tx);
                drive_transaction(tx);
                seq_item_port.item_done();
            end
        endtask
        
        task drive_transaction(apb_transaction tx);
            // Fase 1: Setup
            @(posedge vif.clk);
            vif.psel <= 1;
            vif.penable <= 0;
            vif.paddr <= tx.addr;
            vif.pwrite <= tx.write;
            if (tx.write) begin
                vif.pwdata <= tx.data;
            end
            
            @(posedge vif.clk);
            
            // Fase 2: Enable
            vif.penable <= 1;
            
            @(posedge vif.clk);
            
            // Fase 3: Esperar ready
            while(vif.pready === 1'b0) begin
                @(posedge vif.clk);
            end
            
            // Fase 4: Capturar respuesta
            if (!tx.write) begin
                tx.data = vif.prdata;
            end
            tx.slverr = vif.pslverr;
            
            // Fase 5: Finalizar
            vif.psel <= 0;
            vif.penable <= 0;
            
            // Reportar error si ocurrió
            if (tx.slverr) begin
                `uvm_warning(get_type_name(), $sformatf("APB %s at addr 0x%0h returned error (pslverr=1)", 
                              tx.write ? "WRITE" : "READ", tx.addr))
            end
            
            `uvm_info(get_type_name(), tx.convert2string(), UVM_HIGH)
        endtask
    endclass : apb_driver

    // =========================================================================
    // APB MONITOR 
    // =========================================================================
    class apb_monitor extends uvm_monitor;
        `uvm_component_utils(apb_monitor)
        
        virtual aligner_if vif;  // ← Cambiado a aligner_if
        uvm_analysis_port #(apb_transaction) ap;
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db#(virtual aligner_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(), "APB interface (aligner_if) not found in config_db")
            end
        endfunction
        
        task run_phase(uvm_phase phase);
            forever begin
                apb_transaction tx = apb_transaction::type_id::create("tx");
                
                // Esperar inicio de transacción
                @(posedge vif.clk);
                while(vif.psel === 1'b0) begin
                    @(posedge vif.clk);
                end
                
                // Capturar setup
                tx.addr = vif.paddr;
                tx.write = vif.pwrite;
                if (tx.write) tx.data = vif.pwdata;
                
                // Esperar enable
                while(vif.penable === 1'b0) begin
                    @(posedge vif.clk);
                end
                
                // Esperar ready
                while(vif.pready === 1'b0) begin
                    @(posedge vif.clk);
                end
                
                // Capturar lectura
                if (!tx.write) tx.data = vif.prdata;
                tx.slverr = vif.pslverr;
                
                ap.write(tx);
                `uvm_info(get_type_name(), tx.convert2string(), UVM_HIGH)
            end
        endtask
    endclass : apb_monitor

    // =========================================================================
    // APB AGENT
    // =========================================================================
    class apb_agent extends uvm_agent;
        `uvm_component_utils(apb_agent)
        
        apb_sequencer sequencer;
        apb_driver    driver;
        apb_monitor   monitor;
        uvm_analysis_port #(apb_transaction) ap;
        
        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction
        
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = apb_sequencer::type_id::create("sequencer", this);
            driver    = apb_driver::type_id::create("driver", this);
            monitor   = apb_monitor::type_id::create("monitor", this);
        endfunction
        
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            monitor.ap.connect(ap);
        endfunction
    endclass : apb_agent

    // =========================================================================
    // APB REG ADAPTER (para RAL)
    // =========================================================================
    class apb_reg_adapter extends uvm_reg_adapter;
        `uvm_object_utils(apb_reg_adapter)
        
        function new(string name = "apb_reg_adapter");
            super.new(name);
            supports_byte_enable = 0;
            provides_responses = 0;
        endfunction
        
        virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
            apb_transaction tx = apb_transaction::type_id::create("tx");
            tx.addr = rw.addr[15:0];
            tx.data = rw.data;
            tx.write = (rw.kind == UVM_WRITE);
            return tx;
        endfunction
        
        virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
            apb_transaction tx;
            if (!$cast(tx, bus_item)) return;
            rw.kind = tx.write ? UVM_WRITE : UVM_READ;
            rw.addr = tx.addr;
            rw.data = tx.data;
            rw.status = tx.slverr ? UVM_NOT_OK : UVM_IS_OK;
        endfunction
    endclass : apb_reg_adapter

    // =========================================================================
    // SECUENCIAS APB
    // =========================================================================
    class apb_base_seq extends uvm_sequence #(apb_transaction);
        `uvm_object_utils(apb_base_seq)
        
        function new(string name = "apb_base_seq");
            super.new(name);
        endfunction
        
        task write_reg(logic [15:0] addr, logic [31:0] data);
            apb_transaction tx = apb_transaction::type_id::create("tx");
            start_item(tx);
            tx.addr = addr;
            tx.data = data;
            tx.write = 1;
            finish_item(tx);
        endtask
        
        task read_reg(logic [15:0] addr, output logic [31:0] data);
            apb_transaction tx = apb_transaction::type_id::create("tx");
            start_item(tx);
            tx.addr = addr;
            tx.write = 0;
            finish_item(tx);
            data = tx.data;
        endtask
    endclass : apb_base_seq

    class apb_config_ctrl_seq extends apb_base_seq;
        `uvm_object_utils(apb_config_ctrl_seq)
        int size; int offset; bit clear;
        function new(string name = "apb_config_ctrl_seq"); super.new(name); endfunction
        task body();
            logic [31:0] ctrl_val = size | (offset << 8) | (clear << 16);
            write_reg(16'h0000, ctrl_val);
        endtask
    endclass : apb_config_ctrl_seq

    class apb_read_status_seq extends apb_base_seq;
        `uvm_object_utils(apb_read_status_seq)
        int cnt_drop, rx_lvl, tx_lvl;
        function new(string name = "apb_read_status_seq"); super.new(name); endfunction
        task body();
            logic [31:0] status;
            read_reg(16'h000C, status);
            cnt_drop = status[7:0]; rx_lvl = status[11:8]; tx_lvl = status[19:16];
        endtask
    endclass : apb_read_status_seq

    class apb_enable_irqs_seq extends apb_base_seq;
        `uvm_object_utils(apb_enable_irqs_seq)
        bit enable_rx_empty=1, enable_rx_full=1, enable_tx_empty=1, enable_tx_full=1, enable_max_drop=1;
        function new(string name = "apb_enable_irqs_seq"); super.new(name); endfunction
        task body();
            logic [31:0] irqen_val = enable_rx_empty | (enable_rx_full<<1) | (enable_tx_empty<<2) | (enable_tx_full<<3) | (enable_max_drop<<4);
            write_reg(16'h00F0, irqen_val);
        endtask
    endclass : apb_enable_irqs_seq

    class apb_clear_irqs_seq extends apb_base_seq;
        `uvm_object_utils(apb_clear_irqs_seq)
        bit clear_rx_empty, clear_rx_full, clear_tx_empty, clear_tx_full, clear_max_drop;
        function new(string name = "apb_clear_irqs_seq"); super.new(name); endfunction
        task body();
            logic [31:0] irq_val = clear_rx_empty | (clear_rx_full<<1) | (clear_tx_empty<<2) | (clear_tx_full<<3) | (clear_max_drop<<4);
            write_reg(16'h00F4, irq_val);
        endtask
    endclass : apb_clear_irqs_seq

endpackage : apb_components_pkg

`endif // APB_COMPONENTS_SV