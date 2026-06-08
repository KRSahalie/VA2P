// aligner_tb_pkg.sv
`ifndef ALIGNER_TB_PKG_SV
`define ALIGNER_TB_PKG_SV

package aligner_tb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import cfs_aligner_ral_pkg::*;

    // =========================================================================
    // TRANSACCIONES MD
    // =========================================================================
    
    class rx_transaction extends uvm_sequence_item;
        `uvm_object_utils_begin(rx_transaction)
            `uvm_field_int(data,   UVM_ALL_ON)
            `uvm_field_int(offset, UVM_ALL_ON)
            `uvm_field_int(size,   UVM_ALL_ON)
            `uvm_field_int(valid,  UVM_ALL_ON)
            `uvm_field_int(err,    UVM_ALL_ON)
        `uvm_object_utils_end

        rand logic [31:0] data;
        rand logic [1:0]  offset;
        rand logic [2:0]  size;
        rand logic        valid;  
        rand logic        err;    
        
        // Constraints
        constraint c_size_not_zero { size inside {3'd1, 3'd2, 3'd3, 3'd4}; }
        
        // Para valid, usar dist o una constraint simple
        constraint c_valid_dist { valid dist {1'b1 := 90, 1'b0 := 10}; }
        
        // Regla de legalidad para el DUT
        constraint c_legal {
            // (4 + offset) % size == 0
            (( (4 + offset) % size ) == 0);
        }
        
        constraint c_size_dist   { size   dist {3'd1:=25, 3'd2:=25, 3'd3:=25, 3'd4:=25}; }
        constraint c_offset_dist { offset dist {2'b00:=40, 2'b01:=20, 2'b10:=20, 2'b11:=20}; }

        function new(string name = "rx_transaction");
            super.new(name);
            valid = 1'b1;  // Valor por defecto
            err = 1'b0;    // Valor por defecto
        endfunction

        function string convert2string();
            return $sformatf("[RX] data=0x%08X offset=%0d size=%0d valid=%0b err=%0b",
                             data, offset, size, valid, err);
        endfunction

        function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            rx_transaction rhs_t;
            if (!$cast(rhs_t, rhs)) return 0;
            return (data == rhs_t.data && offset == rhs_t.offset &&
                    size == rhs_t.size && valid == rhs_t.valid);
        endfunction
    endclass : rx_transaction

    // =========================================================================
    // RX TRANSACTION ILEGAL (hereda de rx_transaction)
    // =========================================================================
    class rx_transaction_illegal extends rx_transaction;
        `uvm_object_utils(rx_transaction_illegal)
        
        // Sobrescribir la constraint de legalidad
        constraint c_force_illegal {
            // (4 + offset) % size != 0
            !( ((4 + offset) % size) == 0 );
        }
        
        function void pre_randomize();
            // Deshabilitar la constraint de legalidad de la clase padre
            c_legal.constraint_mode(0);
            c_size_not_zero.constraint_mode(1);
        endfunction
        
        function new(string name = "rx_transaction_illegal");
            super.new(name);
        endfunction
    endclass : rx_transaction_illegal

    // =========================================================================
    // TX TRANSACTION
    // =========================================================================
    class tx_transaction extends uvm_sequence_item;
        `uvm_object_utils_begin(tx_transaction)
            `uvm_field_int(data,   UVM_ALL_ON)
            `uvm_field_int(offset, UVM_ALL_ON)
            `uvm_field_int(size,   UVM_ALL_ON)
            `uvm_field_int(valid,  UVM_ALL_ON)
            `uvm_field_int(err,    UVM_ALL_ON)
        `uvm_object_utils_end

        rand logic [31:0] data;
        rand logic [1:0]  offset;
        rand logic [2:0]  size;
        rand logic        valid;
        rand logic        err;

        function new(string name = "tx_transaction");
            super.new(name);
            offset = 2'b00;  // TX offset siempre debe ser 0 según especificación
            err = 1'b0;
            valid = 1'b1;
        endfunction
        
        // Restricción: offset siempre debe ser 0
        constraint c_offset_zero { offset == 2'b00; }
        
        // Restricción: size debe ser válido
        constraint c_size_valid { size inside {3'd1, 3'd2, 3'd3, 3'd4}; }

        function string convert2string();
            return $sformatf("[TX] data=0x%08X offset=%0d size=%0d valid=%0b err=%0b",
                             data, offset, size, valid, err);
        endfunction

        function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            tx_transaction rhs_t;
            if (!$cast(rhs_t, rhs)) return 0;
            return (data == rhs_t.data && offset == rhs_t.offset &&
                    size == rhs_t.size && valid == rhs_t.valid);
        endfunction
    endclass : tx_transaction

    // =========================================================================
    // IRQ TRANSACTION
    // =========================================================================
    class irq_transaction extends uvm_sequence_item;
        `uvm_object_utils_begin(irq_transaction)
            `uvm_field_int(irq_detected, UVM_ALL_ON)
            `uvm_field_int(timestamp,    UVM_ALL_ON)
        `uvm_object_utils_end
        
        bit irq_detected;
        time timestamp;
        
        function new(string name = "irq_transaction");
            super.new(name);
        endfunction
        
        function string convert2string();
            return $sformatf("[IRQ] @ %0t", timestamp);
        endfunction
    endclass : irq_transaction

    // =========================================================================
    // ANALYSIS IMP DECLARATIONS
    // =========================================================================
    `uvm_analysis_imp_decl(_rx)
    `uvm_analysis_imp_decl(_tx)
    `uvm_analysis_imp_decl(_irq)

endpackage : aligner_tb_pkg

`endif // ALIGNER_TB_PKG_SV