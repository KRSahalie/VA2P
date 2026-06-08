// =============================================================================
// aligner_tb_pkg.sv
// Package principal del testbench — importar DESPUÉS de cfs_aligner_ral_pkg
//
// Este package declara el macro de analysis imp necesario para el scoreboard
// y re-exporta todos los tipos del TB para que sean visibles en tb_top.
//
// NOTA: Los archivos individuales de cada clase se compilan como parte de
// este package. El orden de compilación correcto está en tb.f
// =============================================================================

package aligner_tb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import cfs_aligner_ral_pkg::*;

    // Necesario para que el scoreboard tenga 3 analysis imports distintos
    `uvm_analysis_imp_decl(_rx)
    `uvm_analysis_imp_decl(_tx)
    `uvm_analysis_imp_decl(_irq)

    // ---- Transactions -------------------------------------------------------
    `include "transactions/rx_transaction.sv"
    `include "transactions/tx_transaction.sv"
    `include "transactions/irq_apb_transaction.sv"

    // ---- APB (NO TOCAR) -----------------------------------------------------
    `include "apb/apb_adapter.sv"
    `include "apb/apb_driver.sv"
    `include "apb/apb_monitor_agent.sv"

    // ---- RX -----------------------------------------------------------------
    `include "rx/rx_driver_monitor_agent.sv"

    // ---- TX -----------------------------------------------------------------
    `include "tx/tx_monitor_ready_driver.sv"

    // ---- IRQ ----------------------------------------------------------------
    `include "irq/irq_monitor.sv"

    // ---- ENV ----------------------------------------------------------------
    `include "env/scoreboard.sv"
    `include "env/aligner_env.sv"

    // ---- Secuencias ---------------------------------------------------------
    `include "sequences/rx_sequences.sv"

    // ---- Tests --------------------------------------------------------------
    `include "tests/test_base.sv"
    `include "tests/tests.sv"

endpackage : aligner_tb_pkg
