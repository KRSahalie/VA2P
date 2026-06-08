// =============================================================================
// aligner_if.sv
// Interface principal del DUT cfs_aligner
// 
//
// Contiene:
//   · Señales MD RX (media-dependent receive)
//   · Señales MD TX (media-dependent transmit)
//   · Señales APB (slave)
//   · Señal IRQ
//   · Clocking blocks: rx_driver_cb, rx_monitor_cb, tx_monitor_cb,
//                      tx_driver_cb, apb_cb, irq_cb
//   · Modports para cada agente
//   · Assertions: rx_hold_when_not_ready, tx_offset_zero, rx_size_not_zero
// =============================================================================

`timescale 1ns/1ps

interface aligner_if (input logic clk, input logic reset_n);

    // -------------------------------------------------------------------------
    // MD RX
    // -------------------------------------------------------------------------
    logic        md_rx_valid;
    logic [31:0] md_rx_data;
    logic [1:0]  md_rx_offset;
    logic [2:0]  md_rx_size;
    logic        md_rx_ready;
    logic        md_rx_err;

    // -------------------------------------------------------------------------
    // MD TX
    // -------------------------------------------------------------------------
    logic        md_tx_valid;
    logic [31:0] md_tx_data;
    logic [1:0]  md_tx_offset;
    logic [2:0]  md_tx_size;
    logic        md_tx_ready;
    logic        md_tx_err;

    // -------------------------------------------------------------------------
    // APB
    // -------------------------------------------------------------------------
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [15:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    // -------------------------------------------------------------------------
    // IRQ
    // -------------------------------------------------------------------------
    logic        irq;

    // -------------------------------------------------------------------------
    // Clocking blocks
    // -------------------------------------------------------------------------
    clocking rx_driver_cb @(posedge clk);
        default input #1step; default output #1;
        output md_rx_valid, md_rx_data, md_rx_offset, md_rx_size;
        input  md_rx_ready, md_rx_err;
    endclocking

    clocking rx_monitor_cb @(posedge clk);
        default input #1step;
        input md_rx_valid, md_rx_data, md_rx_offset, md_rx_size, md_rx_ready, md_rx_err;
    endclocking

    clocking tx_monitor_cb @(posedge clk);
        default input #1step;
        input md_tx_valid, md_tx_data, md_tx_offset, md_tx_size, md_tx_ready, md_tx_err;
    endclocking

    clocking tx_driver_cb @(posedge clk);
        default input #1step; default output #1;
        output md_tx_ready;
    endclocking

    clocking apb_cb @(posedge clk);
        default input #1step; default output #1;
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    clocking irq_cb @(posedge clk);
        default input #1step;
        input irq;
    endclocking

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport rx_driver_mp  (clocking rx_driver_cb,  input clk, reset_n);
    modport rx_monitor_mp (clocking rx_monitor_cb, input clk, reset_n);
    modport tx_driver_mp  (clocking tx_driver_cb,  input clk, reset_n);
    modport tx_monitor_mp (clocking tx_monitor_cb, input clk, reset_n);
    modport irq_mp        (clocking irq_cb,        input clk, reset_n);

    // -------------------------------------------------------------------------
    // Assertions
    // -------------------------------------------------------------------------

    // RX: mientras valid=1 y ready=0, el dato no puede cambiar
    property rx_hold_when_not_ready;
        @(posedge clk) disable iff (!reset_n)
        (md_rx_valid && !md_rx_ready) |=>
            ($stable(md_rx_data) && $stable(md_rx_offset) && $stable(md_rx_size));
    endproperty
    ast_rx_hold: assert property (rx_hold_when_not_ready)
        else $error("[IF] RX dato cambió con ready=0");

    // TX: el offset de salida siempre debe ser 0
    property tx_offset_zero;
        @(posedge clk) disable iff (!reset_n)
        md_tx_valid |-> (md_tx_offset == 2'b00);
    endproperty
    ast_tx_offset: assert property (tx_offset_zero)
        else $error("[IF] md_tx_offset != 0");

    // RX: size=0 es ilegal
    property rx_size_not_zero;
        @(posedge clk) disable iff (!reset_n)
        md_rx_valid |-> (md_rx_size != 3'd0);
    endproperty
    ast_rx_size: assert property (rx_size_not_zero)
        else $error("[IF] md_rx_size=0 ilegal");

endinterface : aligner_if
