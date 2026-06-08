// tb_top.sv
`timescale 1ns/1ps

`include "uvm_macros.svh"

// ============================================================================
// INTERFACES
// ============================================================================
`include "aligner_if.sv"

// ============================================================================
// RTL 
// ============================================================================
`include "dut.sv" //pegamos todo el dut en un archivo 


// ============================================================================
// RAL PACKAGE (generado por PeakRDL)
// ============================================================================
`include "cfs_aligner_ral_pkg.sv"

// ============================================================================
// COMPONENTES APB
// ============================================================================
`include "apb_componentes.sv"

// ============================================================================
// COMPONENTES MD Y TB
// ============================================================================
`include "aligner_tb_pkg.sv"
`include "md_componentes.sv"
`include "scoreboard.sv"
`include "aligner_env.sv"
`include "md_sequences.sv"

// ============================================================================
// TESTS
// ============================================================================
`include "test_general.sv"

// ============================================================================
// MODULO PRINCIPAL
// ============================================================================
module tb_top;
    
    import uvm_pkg::*;
    import apb_components_pkg::*;
    import md_components_pkg::*;
    import aligner_tb_pkg::*;
    import scoreboard_pkg::*;
    import aligner_env_pkg::*;
    import md_sequences_pkg::*;
    import cfs_aligner_ral_pkg::*;
    
    // ========================================================================
    // Señales
    // ========================================================================
    logic clk = 0;
    logic reset_n = 0;
    
    // Interfaz unificada
    aligner_if vif(clk, reset_n);
    
    // ========================================================================
    // DUT 
    // ========================================================================
    cfs_aligner #(
        .ALGN_DATA_WIDTH(32),
        .FIFO_DEPTH(8)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        
        // MD RX
        .md_rx_valid(vif.md_rx_valid),
        .md_rx_data(vif.md_rx_data),
        .md_rx_offset(vif.md_rx_offset),
        .md_rx_size(vif.md_rx_size),
        .md_rx_ready(vif.md_rx_ready),
        .md_rx_err(vif.md_rx_err),
        
        // MD TX
        .md_tx_valid(vif.md_tx_valid),
        .md_tx_data(vif.md_tx_data),
        .md_tx_offset(vif.md_tx_offset),
        .md_tx_size(vif.md_tx_size),
        .md_tx_ready(vif.md_tx_ready),
        .md_tx_err(vif.md_tx_err),
        
        // APB
        .paddr(vif.paddr),
        .pwrite(vif.pwrite),
        .psel(vif.psel),
        .penable(vif.penable),
        .pwdata(vif.pwdata),
        .pready(vif.pready),
        .prdata(vif.prdata),
        .pslverr(vif.pslverr),
        
        // IRQ
        .irq(vif.irq)
    );
    
    // ========================================================================
    // Clock generation (50MHz, período 20ns)
    // ========================================================================
    always #10 clk = ~clk;
    
    // ========================================================================
    // Reset generation
    // ========================================================================
    initial begin
        reset_n = 0;
        repeat(10) @(posedge clk);
        reset_n = 1;
        `uvm_info("TB_TOP", "Reset deasserted", UVM_LOW)
    end
    
    // ========================================================================
    // Configuración de interfaces en config_db
    // ========================================================================
    initial begin
        // MD interfaces
        uvm_config_db #(virtual aligner_if.rx_driver_mp)::set(null, "*", "rx_vif", vif);
        uvm_config_db #(virtual aligner_if.rx_monitor_mp)::set(null, "*", "rx_vif", vif);
        uvm_config_db #(virtual aligner_if.tx_driver_mp)::set(null, "*", "tx_vif", vif);
        uvm_config_db #(virtual aligner_if.tx_monitor_mp)::set(null, "*", "tx_vif", vif);
        uvm_config_db #(virtual aligner_if.irq_mp)::set(null, "*", "irq_vif", vif);
        
        // APB interface 
        uvm_config_db #(virtual aligner_if)::set(null, "*", "vif", vif);
        
        `uvm_info("TB_TOP", "All interfaces set in config_db", UVM_LOW)
    end
    
    // ========================================================================
    // RAL model
    // ========================================================================
    cfs_aligner_regs regmodel;
    
    initial begin
        regmodel = cfs_aligner_regs::type_id::create("regmodel");
        regmodel.build();
        regmodel.reset();
        uvm_config_db #(cfs_aligner_regs)::set(null, "*", "reg_model", regmodel);
        `uvm_info("TB_TOP", "RAL model created and set in config_db", UVM_LOW)
    end
    
    // ========================================================================
    // Ejecutar test
    // ========================================================================
    initial begin
        run_test();
    end
    
endmodule : tb_top