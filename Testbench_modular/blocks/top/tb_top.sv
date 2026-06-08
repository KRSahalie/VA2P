// =============================================================================
// tb_top.sv
// Top del testbench — instancia el DUT, la interface y arranca UVM
//
// Responsabilidades:
//   · Genera clk (período 10ns) y reset_n (activo 10 ciclos)
//   · Instancia aligner_if y conecta el DUT cfs_aligner
//   · Registra todas las interfaces en uvm_config_db
//   · Watchdog de 50000 ciclos [FIX-WD]
//   · Llama run_test() para iniciar la fase UVM
//
// Interfaces registradas:
//   rx_vif  → rx_driver_mp  (rx_driver)
//   rx_vif  → rx_monitor_mp (rx_monitor)
//   tx_vif  → tx_monitor_mp (tx_monitor)
//   tx_vif  → tx_driver_mp  (tx_ready_driver)
//   apb_vif → aligner_if    (apb_driver + apb_monitor, sin modport)
//   irq_vif → irq_mp        (irq_monitor)
// =============================================================================

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
import cfs_aligner_ral_pkg::*;
import aligner_tb_pkg::*;

module tb_top;

    // -------------------------------------------------------------------------
    // Clock y Reset
    // -------------------------------------------------------------------------
    logic clk;
    logic reset_n;

    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    initial begin
        reset_n = 1'b0;
        repeat(10) @(posedge clk);  // reset activo 10 ciclos = 100ns
        reset_n = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Interface y DUT
    // -------------------------------------------------------------------------
    aligner_if dut_if (.clk(clk), .reset_n(reset_n));

    // md_tx_err no es generado por el testbench — se fuerza a 0
    assign dut_if.md_tx_err = 1'b0;

    cfs_aligner dut (
        .clk          (clk),
        .reset_n      (reset_n),
        .paddr        (dut_if.paddr),
        .pwrite       (dut_if.pwrite),
        .psel         (dut_if.psel),
        .penable      (dut_if.penable),
        .pwdata       (dut_if.pwdata),
        .pready       (dut_if.pready),
        .prdata       (dut_if.prdata),
        .pslverr      (dut_if.pslverr),
        .md_rx_valid  (dut_if.md_rx_valid),
        .md_rx_data   (dut_if.md_rx_data),
        .md_rx_offset (dut_if.md_rx_offset),
        .md_rx_size   (dut_if.md_rx_size),
        .md_rx_ready  (dut_if.md_rx_ready),
        .md_rx_err    (dut_if.md_rx_err),
        .md_tx_valid  (dut_if.md_tx_valid),
        .md_tx_data   (dut_if.md_tx_data),
        .md_tx_offset (dut_if.md_tx_offset),
        .md_tx_size   (dut_if.md_tx_size),
        .md_tx_ready  (dut_if.md_tx_ready),
        .md_tx_err    (dut_if.md_tx_err),
        .irq          (dut_if.irq)
    );

    // -------------------------------------------------------------------------
    // Watchdog [FIX-WD]: 50000 ciclos máximo
    // -------------------------------------------------------------------------
    initial begin
        repeat(50000) @(posedge clk);
        $display("[WATCHDOG] Timeout tras 50000 ciclos");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Registro de interfaces en config_db + arranque UVM
    // -------------------------------------------------------------------------
    initial begin
        // RX: el driver usa rx_driver_mp, el monitor usa rx_monitor_mp
        uvm_config_db #(virtual aligner_if.rx_driver_mp)::set(
            null, "uvm_test_top.*", "rx_vif", dut_if);
        uvm_config_db #(virtual aligner_if.rx_monitor_mp)::set(
            null, "uvm_test_top.*", "rx_vif", dut_if);

        // TX: el monitor usa tx_monitor_mp, el ready driver usa tx_driver_mp
        uvm_config_db #(virtual aligner_if.tx_monitor_mp)::set(
            null, "uvm_test_top.*", "tx_vif", dut_if);
        uvm_config_db #(virtual aligner_if.tx_driver_mp)::set(
            null, "uvm_test_top.*", "tx_vif", dut_if);

        // APB: sin modport (requerido por apb_driver y apb_monitor)
        uvm_config_db #(virtual aligner_if)::set(
            null, "uvm_test_top.*", "apb_vif", dut_if);

        // IRQ: usa irq_mp
        uvm_config_db #(virtual aligner_if.irq_mp)::set(
            null, "uvm_test_top.*", "irq_vif", dut_if);

        run_test();
    end

endmodule : tb_top
