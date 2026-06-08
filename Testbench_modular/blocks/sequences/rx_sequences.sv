// =============================================================================
// rx_sequences.sv
// Secuencias RX del testbench cfs_aligner
// =============================================================================

// =============================================================================
// rx_fixed_seq
// Envía N paquetes RX con offset y size fijos.
// Útil para test_basic_align y test_offset_align donde se controla exactamente
// la combinación (offset, size) que el DUT va a recibir.
//
// Parámetros configurables:
//   n_pkts        — número de paquetes a enviar (default 8)
//   fixed_offset  — offset fijo para todos los paquetes (default 2'b00)
//   fixed_size    — size fijo para todos los paquetes (default 3'd4)
// =============================================================================

class rx_fixed_seq extends uvm_sequence #(rx_transaction);
    `uvm_object_utils(rx_fixed_seq)

    int unsigned n_pkts       = 8;
    logic [1:0]  fixed_offset = 2'b00;
    logic [2:0]  fixed_size   = 3'd4;

    function new(string name = "rx_fixed_seq");
        super.new(name);
    endfunction

    task body();
        repeat(n_pkts) begin
            rx_transaction tr = rx_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {
                valid  == 1'b1;
                offset == fixed_offset;
                size   == fixed_size;
            });
            finish_item(tr);
        end
    endtask

endclass : rx_fixed_seq


// =============================================================================
// rx_mixed_seq
// Envía N paquetes legales seguidos de N paquetes ilegales.
//
// Legales  : offset=0, size=4 → (4+0)%4=0 → pasan
// Ilegales : rx_transaction_illegal → fuerza drop en el DUT
//
// Parámetros configurables:
//   n_legal   — paquetes legales (default 4)
//   n_illegal — paquetes ilegales (default 4)
// =============================================================================

class rx_mixed_seq extends uvm_sequence #(rx_transaction);
    `uvm_object_utils(rx_mixed_seq)

    int unsigned n_legal   = 4;
    int unsigned n_illegal = 4;

    function new(string name = "rx_mixed_seq");
        super.new(name);
    endfunction

    task body();
        // Paquetes legales: (4+0)%4=0
        repeat(n_legal) begin
            rx_transaction tr = rx_transaction::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with {
                valid  == 1'b1;
                offset == 2'b00;
                size   == 3'd4;
            });
            finish_item(tr);
        end
        // Paquetes ilegales: (4+1)%3=2≠0 o (4+3)%2=1≠0 → drop
        repeat(n_illegal) begin
            rx_transaction_illegal tr =
                rx_transaction_illegal::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize());
            finish_item(tr);
        end
    endtask

endclass : rx_mixed_seq
