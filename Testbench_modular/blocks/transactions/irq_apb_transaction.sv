// =============================================================================
// irq_transaction.sv
// Ítem de secuencia para eventos de IRQ (solo monitor)
// =============================================================================

class irq_transaction extends uvm_sequence_item;
    `uvm_object_utils_begin(irq_transaction)
        `uvm_field_int(irq_detected, UVM_ALL_ON)
        `uvm_field_int(timestamp,    UVM_ALL_ON)
    `uvm_object_utils_end

    logic irq_detected;
    time  timestamp;

    function new(string name = "irq_transaction");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("[IRQ] @ %0t", timestamp);
    endfunction

endclass : irq_transaction


// =============================================================================
// apb_transaction.sv
// Ítem de secuencia para el bus APB (driver + monitor + adapter RAL)
// — NO TOCAR: usada internamente por el APB agent y el reg adapter
// =============================================================================

class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils_begin(apb_transaction)
        `uvm_field_int(addr,   UVM_ALL_ON)
        `uvm_field_int(data,   UVM_ALL_ON)
        `uvm_field_int(write,  UVM_ALL_ON)
        `uvm_field_int(slverr, UVM_ALL_ON)
    `uvm_object_utils_end

    rand logic [15:0] addr;
    rand logic [31:0] data;
    rand logic        write;
         logic        slverr;

    function new(string name = "apb_transaction");
        super.new(name);
    endfunction

endclass : apb_transaction
