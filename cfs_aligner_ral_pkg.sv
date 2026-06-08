// cfs_regs_ral.sv 
package cfs_aligner_ral_pkg;
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    // reg - cfs_aligner_regs::ctrl
    class cfs_aligner_regs__ctrl extends uvm_reg;
        `uvm_object_utils(cfs_aligner_regs__ctrl)  
        
        rand uvm_reg_field size;
        rand uvm_reg_field reserved0;
        rand uvm_reg_field offset;
        rand uvm_reg_field reserved1;
        rand uvm_reg_field clr;
        rand uvm_reg_field reserved2;

        function new(string name = "cfs_aligner_regs__ctrl");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.size = new("size");
            this.size.configure(this, 3, 0, "RW", 1, 'h1, 1, 1, 0);
            this.reserved0 = new("reserved0");
            this.reserved0.configure(this, 5, 3, "RO", 1, 'h0, 1, 1, 0);
            this.offset = new("offset");
            this.offset.configure(this, 2, 8, "RW", 1, 'h0, 1, 1, 0);
            this.reserved1 = new("reserved1");
            this.reserved1.configure(this, 6, 10, "RO", 1, 'h0, 1, 1, 0);
            this.clr = new("clr");
            this.clr.configure(this, 1, 16, "WO", 1, 'h0, 1, 1, 0);
            this.reserved2 = new("reserved2");
            this.reserved2.configure(this, 15, 17, "RO", 1, 'h0, 1, 1, 0);
        endfunction
    endclass

    // reg - cfs_aligner_regs::status
    class cfs_aligner_regs__status extends uvm_reg;
        `uvm_object_utils(cfs_aligner_regs__status)  // ← AGREGAR
        
        rand uvm_reg_field cnt_drop;
        rand uvm_reg_field rx_lvl;
        rand uvm_reg_field reserved0;
        rand uvm_reg_field tx_lvl;
        rand uvm_reg_field reserved1;

        function new(string name = "cfs_aligner_regs__status");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.cnt_drop = new("cnt_drop");
            this.cnt_drop.configure(this, 8, 0, "RO", 1, 'h0, 1, 1, 0);
            this.rx_lvl = new("rx_lvl");
            this.rx_lvl.configure(this, 4, 8, "RO", 1, 'h0, 1, 1, 0);
            this.reserved0 = new("reserved0");
            this.reserved0.configure(this, 4, 12, "RO", 1, 'h0, 1, 1, 0);
            this.tx_lvl = new("tx_lvl");
            this.tx_lvl.configure(this, 4, 16, "RO", 1, 'h0, 1, 1, 0);
            this.reserved1 = new("reserved1");
            this.reserved1.configure(this, 12, 20, "RO", 1, 'h0, 1, 1, 0);
        endfunction
    endclass

    // reg - cfs_aligner_regs::irqen
    class cfs_aligner_regs__irqen extends uvm_reg;
        `uvm_object_utils(cfs_aligner_regs__irqen)
        
        rand uvm_reg_field rx_fifo_empty;
        rand uvm_reg_field rx_fifo_full;
        rand uvm_reg_field tx_fifo_empty;
        rand uvm_reg_field tx_fifo_full;
        rand uvm_reg_field max_drop;
        rand uvm_reg_field reserved;

        function new(string name = "cfs_aligner_regs__irqen");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.rx_fifo_empty = new("rx_fifo_empty");
            this.rx_fifo_empty.configure(this, 1, 0, "RW", 1, 'h1, 1, 1, 0);
            this.rx_fifo_full = new("rx_fifo_full");
            this.rx_fifo_full.configure(this, 1, 1, "RW", 1, 'h1, 1, 1, 0);
            this.tx_fifo_empty = new("tx_fifo_empty");
            this.tx_fifo_empty.configure(this, 1, 2, "RW", 1, 'h1, 1, 1, 0);
            this.tx_fifo_full = new("tx_fifo_full");
            this.tx_fifo_full.configure(this, 1, 3, "RW", 1, 'h1, 1, 1, 0);
            this.max_drop = new("max_drop");
            this.max_drop.configure(this, 1, 4, "RW", 1, 'h1, 1, 1, 0);
            this.reserved = new("reserved");
            this.reserved.configure(this, 27, 5, "RO", 1, 'h0, 1, 1, 0);
        endfunction
    endclass

    // reg - cfs_aligner_regs::irq
    class cfs_aligner_regs__irq extends uvm_reg;
        `uvm_object_utils(cfs_aligner_regs__irq)  
        
        rand uvm_reg_field rx_fifo_empty;
        rand uvm_reg_field rx_fifo_full;
        rand uvm_reg_field tx_fifo_empty;
        rand uvm_reg_field tx_fifo_full;
        rand uvm_reg_field max_drop;
        rand uvm_reg_field reserved;

        function new(string name = "cfs_aligner_regs__irq");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.rx_fifo_empty = new("rx_fifo_empty");
            this.rx_fifo_empty.configure(this, 1, 0, "W1C", 1, 'h0, 1, 1, 0);
            this.rx_fifo_full = new("rx_fifo_full");
            this.rx_fifo_full.configure(this, 1, 1, "W1C", 1, 'h0, 1, 1, 0);
            this.tx_fifo_empty = new("tx_fifo_empty");
            this.tx_fifo_empty.configure(this, 1, 2, "W1C", 1, 'h0, 1, 1, 0);
            this.tx_fifo_full = new("tx_fifo_full");
            this.tx_fifo_full.configure(this, 1, 3, "W1C", 1, 'h0, 1, 1, 0);
            this.max_drop = new("max_drop");
            this.max_drop.configure(this, 1, 4, "W1C", 1, 'h0, 1, 1, 0);
            this.reserved = new("reserved");
            this.reserved.configure(this, 27, 5, "RO", 1, 'h0, 1, 1, 0);
        endfunction
    endclass

    // addrmap - cfs_aligner_regs
    class cfs_aligner_regs extends uvm_reg_block;
        `uvm_object_utils(cfs_aligner_regs)  
        
        rand cfs_aligner_regs__ctrl ctrl;
        rand cfs_aligner_regs__status status;
        rand cfs_aligner_regs__irqen irqen;
        rand cfs_aligner_regs__irq irq;

        function new(string name = "cfs_aligner_regs");
            super.new(name);
        endfunction

        virtual function void build();
            this.default_map = create_map("reg_map", 0, 4, UVM_NO_ENDIAN);
            
            this.ctrl = cfs_aligner_regs__ctrl::type_id::create("ctrl");
            this.ctrl.configure(this);
            this.ctrl.build();
            this.default_map.add_reg(this.ctrl, 'h0);
            
            this.status = cfs_aligner_regs__status::type_id::create("status");
            this.status.configure(this);
            this.status.build();
            this.default_map.add_reg(this.status, 'hc);
            
            this.irqen = cfs_aligner_regs__irqen::type_id::create("irqen");
            this.irqen.configure(this);
            this.irqen.build();
            this.default_map.add_reg(this.irqen, 'hf0);
            
            this.irq = cfs_aligner_regs__irq::type_id::create("irq");
            this.irq.configure(this);
            this.irq.build();
            this.default_map.add_reg(this.irq, 'hf4);
        endfunction
    endclass

endpackage