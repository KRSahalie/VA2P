// md_sequences.sv
`ifndef MD_SEQUENCES_SV
`define MD_SEQUENCES_SV

package md_sequences_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import aligner_tb_pkg::*;

    class md_base_seq extends uvm_sequence #(rx_transaction);
        `uvm_object_utils(md_base_seq)
        
        function new(string name = "md_base_seq");
            super.new(name);
        endfunction
        
        task body();
            // Vacío
        endtask
    endclass : md_base_seq

    // =========================================================================
    // Secuencia con paquetes legales de tamaño fijo
    // =========================================================================
    class rx_fixed_seq extends md_base_seq;
        `uvm_object_utils(rx_fixed_seq)
        
        int unsigned n_pkts      = 8;
        logic [1:0]  fixed_offset = 2'b00;
        logic [2:0]  fixed_size   = 3'd2;
        string patron = "RANDOM";
        int contador  = 0;

        function new(string name = "rx_fixed_seq");
            super.new(name);
        endfunction
        
        function logic [31:0] generar_dato();
            logic [31:0] resultado;
            case(patron)
                "INCR":  resultado = contador++;
                "DECR":  resultado = contador--;
                "FIXED": resultado = 32'hA5A5A5A5;
                "ZEROS": resultado = 32'h00000000;
                "ONES":  resultado = 32'hFFFFFFFF;
                default: resultado = $urandom();
            endcase
            return resultado;
        endfunction

        task body();
            for (int i = 0; i < n_pkts; i++) begin
                rx_transaction tr = rx_transaction::type_id::create("tr");
                start_item(tr);
                assert(tr.randomize() with {
                    valid  == 1'b1;
                    offset == fixed_offset;
                    size   == fixed_size;
                });
                tr.data = generar_dato();
                finish_item(tr);
                #($urandom_range(1, 20));
            end
        endtask
    endclass : rx_fixed_seq

    // =========================================================================
    // Secuencia mixta (legales + ilegales)
    // =========================================================================
    class rx_mixed_seq extends md_base_seq;
        `uvm_object_utils(rx_mixed_seq)
        
        int unsigned n_legal   = 4;
        int unsigned n_illegal = 4;
        string patron  = "RANDOM";
        int contador   = 0;
        
        // Combinaciones (offset, size) legales: (4+offset)%size == 0
        int legal_sizes[$];
        int legal_offsets[$];
        
        function new(string name = "rx_mixed_seq");
            super.new(name);
            // Pre-calcular todas las combinaciones legales
            legal_sizes.delete();
            legal_offsets.delete();
            for (int s = 1; s <= 4; s++) begin
                for (int o = 0; o < 4; o++) begin
                    if (((4 + o) % s) == 0) begin
                        legal_sizes.push_back(s);
                        legal_offsets.push_back(o);
                    end
                end
            end
        endfunction
        
        function logic [31:0] generar_dato();
            logic [31:0] resultado;
            case(patron)
                "INCR":  resultado = contador++;
                "DECR":  resultado = contador--;
                "FIXED": resultado = 32'hA5A5A5A5;
                "ZEROS": resultado = 32'h00000000;
                "ONES":  resultado = 32'hFFFFFFFF;
                default: resultado = $urandom();
            endcase
            return resultado;
        endfunction
        
        task send_legal();
            rx_transaction tr;
            int idx;
            int sel_size;
            int sel_offset;
            tr         = rx_transaction::type_id::create("tr");
            idx        = $urandom_range(legal_sizes.size() - 1);
            sel_size   = legal_sizes[idx];
            sel_offset = legal_offsets[idx];
            start_item(tr);
            assert(tr.randomize() with {
                valid  == 1'b1;
                size   == sel_size;
                offset == sel_offset;
            });
            tr.data = generar_dato();
            finish_item(tr);
            `uvm_info(get_type_name(),
                $sformatf("Enviado LEGAL: off=%0d size=%0d data=0x%08X",
                          tr.offset, tr.size, tr.data), UVM_MEDIUM)
            #($urandom_range(1, 20));
        endtask
        
        task send_illegal();
            rx_transaction_illegal tr_ill;
            rx_transaction         tr_base;
            tr_ill = rx_transaction_illegal::type_id::create("tr");
            assert(tr_ill.randomize());
            tr_ill.data = generar_dato();
            // Cast a clase base para poder usar el sequencer de rx_transaction
            if (!$cast(tr_base, tr_ill))
                `uvm_fatal(get_type_name(), "Cast rx_transaction_illegal -> rx_transaction falló")
            start_item(tr_base);
            finish_item(tr_base);
            `uvm_info(get_type_name(),
                $sformatf("Enviado ILEGAL: off=%0d size=%0d data=0x%08X",
                          tr_base.offset, tr_base.size, tr_base.data), UVM_MEDIUM)
            #($urandom_range(1, 20));
        endtask
        
        task body();
            bit send_list[];
            int total;
            int j;
            bit tmp;
            total = n_legal + n_illegal;
            send_list = new[total];
            
            for (int i = 0; i < total; i++)
                send_list[i] = (i < n_legal) ? 1'b1 : 1'b0;
            
            // Shuffle Fisher-Yates
            for (int i = total - 1; i > 0; i--) begin
                j            = $urandom_range(i);
                tmp          = send_list[i];
                send_list[i] = send_list[j];
                send_list[j] = tmp;
            end
            
            // Enviar en orden mezclado
            for (int i = 0; i < total; i++) begin
                if (send_list[i]) send_legal();
                else              send_illegal();
            end
        endtask
    endclass : rx_mixed_seq

    // =========================================================================
    // Secuencia de estrés
    // =========================================================================
    class rx_stress_seq extends md_base_seq;
        `uvm_object_utils(rx_stress_seq)
        
        int unsigned n_pkts = 100;
        string patron = "RANDOM";
        int contador  = 0;

        function new(string name = "rx_stress_seq");
            super.new(name);
        endfunction
        
        function logic [31:0] generar_dato();
            logic [31:0] resultado;
            case(patron)
                "INCR":  resultado = contador++;
                "DECR":  resultado = contador--;
                "FIXED": resultado = 32'hA5A5A5A5;
                "ZEROS": resultado = 32'h00000000;
                "ONES":  resultado = 32'hFFFFFFFF;
                default: resultado = $urandom();
            endcase
            return resultado;
        endfunction

        task body();
            repeat(n_pkts) begin
                rx_transaction tr = rx_transaction::type_id::create("tr");
                start_item(tr);
                assert(tr.randomize());
                tr.data = generar_dato();
                finish_item(tr);
                if ($urandom_range(0, 100) < 30) begin
                    #($urandom_range(10, 100));
                end
            end
        endtask
    endclass : rx_stress_seq

endpackage : md_sequences_pkg

`endif // MD_SEQUENCES_SV