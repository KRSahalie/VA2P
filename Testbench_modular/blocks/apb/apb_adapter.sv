// =============================================================================
// apb_adapter.sv
// Adapter RAL ↔ APB 
//
// Traduce uvm_reg_bus_op ↔ apb_transaction para que el UVM Register Layer
// pueda hablar con el sequencer APB transparentemente.
// =============================================================================

class apb_adapter extends uvm_reg_adapter;
    `uvm_object_utils(apb_adapter)

    function new(string name = "apb_adapter");
        super.new(name);
        supports_byte_enable = 0;
        provides_responses   = 1;
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        apb_transaction tr = apb_transaction::type_id::create("tr");
        tr.addr  = rw.addr[15:0];
        tr.data  = rw.data;
        tr.write = (rw.kind == UVM_WRITE);
        return tr;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item,
                                  ref uvm_reg_bus_op rw);
        apb_transaction tr;
        if (!$cast(tr, bus_item))
            `uvm_fatal("APB_ADAPT", "Cast falló")
        rw.kind   = tr.write ? UVM_WRITE : UVM_READ;
        rw.addr   = tr.addr;
        rw.data   = tr.data;
        rw.status = tr.slverr ? UVM_NOT_OK : UVM_IS_OK;
    endfunction

endclass : apb_adapter
