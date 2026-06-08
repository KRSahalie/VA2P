// tb_top_apb_only.sv
`timescale 1ns/1ps

`include "uvm_macros.svh"

// RAL package
`include "cfs_regs_ral.sv"

// Interfaces
`include "apb_if.sv"

// RTL
`include "cfs_aligner.v"
`include "cfs_aligner_core.v"
`include "cfs_regs.v"
`include "cfs_rx_ctrl.v"
`include "cfs_ctrl.v"
`include "cfs_tx_ctrl.v"
`include "cfs_synch.v"
`include "cfs_synch_fifo.v"
`include "cfs_edge_detect.v"

// UVM Components
`include "apb_transaction.sv"
`include "apb_sequencer.sv"
`include "apb_driver.sv"
`include "monitor_apb.sv"
`include "agente_apb.sv"
`include "reg_adapter.sv"
`include "apb_sequences.sv"

// Environment
`include "env_prueba_apb-ral.sv"

// TESTS 
`include "test_apb_basic_rw.sv"

module tb_top_apb_only;
    
    import uvm_pkg::*;
    import cfs_aligner_ral_pkg::*;
    
    // Clock y reset
    logic clk = 0;
    logic reset_n = 0;
    
    // Interfaz APB
    apb_if apb_vif (clk, reset_n);
    
    // Instanciar DUT
    cfs_aligner #(
        .ALGN_DATA_WIDTH(32),
        .FIFO_DEPTH(8)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .paddr(apb_vif.paddr),
        .pwrite(apb_vif.pwrite),
        .psel(apb_vif.psel),
        .penable(apb_vif.penable),
        .pwdata(apb_vif.pwdata),
        .pready(apb_vif.pready),
        .prdata(apb_vif.prdata),
        .pslverr(apb_vif.pslverr),
        .md_rx_valid(1'b0),
        .md_rx_data(32'b0),
        .md_rx_offset(2'b0),
        .md_rx_size(3'b0),
        .md_rx_ready(),
        .md_rx_err(),
        .md_tx_valid(),
        .md_tx_data(),
        .md_tx_offset(),
        .md_tx_size(),
        .md_tx_ready(1'b0),
        .md_tx_err(1'b0),
        .irq()
    );
    
    // Clock generation
    always #5 clk = ~clk;
    
    // Reset generation
    initial begin
        reset_n = 0;
        repeat(5) @(posedge clk);
        reset_n = 1;
        `uvm_info("TB_TOP", "Reset deasserted", UVM_LOW)
    end
    
    // Configurar interfaz en config_db
    initial begin
        uvm_config_db#(virtual apb_if)::set(null, "*", "vif", apb_vif);
        `uvm_info("TB_TOP", "APB interface set in config_db", UVM_LOW)
    end
    
    initial begin
        run_test("test_apb_basic_rw");  
    end
    
    // Dump waves
    initial begin
        $dumpfile("waves_apb_only.vcd");
        $dumpvars(0, tb_top_apb_only);
    end
    
endmodule