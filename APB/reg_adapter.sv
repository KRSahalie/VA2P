// reg_adapter.sv
`ifndef REG_ADAPTER_SV
`define REG_ADAPTER_SV

class reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(reg_adapter)
    
    function new(string name = "reg_adapter");
        super.new(name);
        supports_byte_enable = 0;
        provides_responses = 0;  
    endfunction
    
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        apb_transaction tx = apb_transaction::type_id::create("tx");
        tx.addr = rw.addr;
        tx.data = rw.data;
        tx.write = (rw.kind == UVM_WRITE);
        tx.slverr = 0;  // Inicializar
        return tx;
    endfunction
    
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        apb_transaction tx;
        if (!$cast(tx, bus_item)) begin
            `uvm_error("REG_ADAPTER", "Failed to cast bus_item to apb_transaction")
            return;
        end
        rw.kind = tx.write ? UVM_WRITE : UVM_READ;
        rw.addr = tx.addr;
        rw.data = tx.data;
        rw.status = tx.slverr ? UVM_NOT_OK : UVM_IS_OK;
    endfunction
    
endclass

`endif