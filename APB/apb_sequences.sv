// sequences/apb_sequences.sv
`ifndef APB_SEQUENCES_SV
`define APB_SEQUENCES_SV

// Secuencia base con helpers
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
endclass


// Secuencia para configurar CTRL
class apb_config_ctrl_seq extends apb_base_seq;
    `uvm_object_utils(apb_config_ctrl_seq)
    
    int size;
    int offset;
    bit clear;
    
    function new(string name = "apb_config_ctrl_seq");
        super.new(name);
    endfunction
    
    task body();
        logic [31:0] ctrl_val;
        ctrl_val = size;
        ctrl_val |= (offset << 8);
        ctrl_val |= (clear << 16);
        write_reg(16'h0000, ctrl_val);
    endtask
endclass


// Secuencia para leer STATUS
class apb_read_status_seq extends apb_base_seq;
    `uvm_object_utils(apb_read_status_seq)
    
    int cnt_drop;
    int rx_lvl;
    int tx_lvl;
    
    function new(string name = "apb_read_status_seq");
        super.new(name);
    endfunction
    
    task body();
        logic [31:0] status;
        read_reg(16'h000C, status);
        cnt_drop = status[7:0];
        rx_lvl = status[11:8];
        tx_lvl = status[19:16];
    endtask
endclass


// Secuencia para habilitar interrupciones
class apb_enable_irqs_seq extends apb_base_seq;
    `uvm_object_utils(apb_enable_irqs_seq)
    
    bit enable_rx_empty = 1;
    bit enable_rx_full = 1;
    bit enable_tx_empty = 1;
    bit enable_tx_full = 1;
    bit enable_max_drop = 1;
    
    function new(string name = "apb_enable_irqs_seq");
        super.new(name);
    endfunction
    
    task body();
        logic [31:0] irqen_val;
        irqen_val = enable_rx_empty;
        irqen_val |= (enable_rx_full << 1);
        irqen_val |= (enable_tx_empty << 2);
        irqen_val |= (enable_tx_full << 3);
        irqen_val |= (enable_max_drop << 4);
        write_reg(16'h00F0, irqen_val);
    endtask
endclass


// Secuencia para limpiar interrupciones (W1C)
class apb_clear_irqs_seq extends apb_base_seq;
    `uvm_object_utils(apb_clear_irqs_seq)
    
    bit clear_rx_empty;
    bit clear_rx_full;
    bit clear_tx_empty;
    bit clear_tx_full;
    bit clear_max_drop;
    
    function new(string name = "apb_clear_irqs_seq");
        super.new(name);
    endfunction
    
    task body();
        logic [31:0] irq_val;
        irq_val = clear_rx_empty;
        irq_val |= (clear_rx_full << 1);
        irq_val |= (clear_tx_empty << 2);
        irq_val |= (clear_tx_full << 3);
        irq_val |= (clear_max_drop << 4);
        write_reg(16'h00F4, irq_val);
    endtask
endclass

`endif