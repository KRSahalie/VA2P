// transactions/apb_transaction.sv
`ifndef APB_TRANSACTION_SV
`define APB_TRANSACTION_SV

class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils(apb_transaction)
    
    // Campos
    rand logic [15:0] addr;
    rand logic [31:0] data;
    rand bit write;
    
    // Respuesta (llenada por driver)
    bit slverr;
    
    // Constraints
    constraint valid_addr {
        addr inside {
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
    
    // Copia (necesaria para el sequencer)
    function void do_copy(uvm_object rhs);
        apb_transaction tx;
        $cast(tx, rhs);
        addr = tx.addr;
        data = tx.data;
        write = tx.write;
        slverr = tx.slverr;
    endfunction
    
endclass

`endif