// aligner_if.sv
interface aligner_if (input logic clk, input logic reset_n);

    // Señales MD RX
    logic        md_rx_valid;
    logic [31:0] md_rx_data;
    logic [1:0]  md_rx_offset;
    logic [2:0]  md_rx_size;
    logic        md_rx_ready;
    logic        md_rx_err;

    // Señales MD TX
    logic        md_tx_valid;
    logic [31:0] md_tx_data;
    logic [1:0]  md_tx_offset;
    logic [2:0]  md_tx_size;
    logic        md_tx_ready;
    logic        md_tx_err;

    // Señales APB
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [15:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
    logic        irq;

    // Clocking blocks - MD RX
    clocking rx_driver_cb @(posedge clk);
        default input #1step; default output #1;
        output md_rx_valid, md_rx_data, md_rx_offset, md_rx_size;
        input  md_rx_ready, md_rx_err;
    endclocking

    clocking rx_monitor_cb @(posedge clk);
        default input #1step;
        input md_rx_valid, md_rx_data, md_rx_offset, md_rx_size, md_rx_ready, md_rx_err;
    endclocking

    // Clocking blocks - MD TX
    clocking tx_monitor_cb @(posedge clk);
        default input #1step;
        input md_tx_valid, md_tx_data, md_tx_offset, md_tx_size, md_tx_ready, md_tx_err;
    endclocking

    clocking tx_driver_cb @(posedge clk);
        default input #1step; default output #1;
        output md_tx_ready;
        input  md_tx_valid, md_tx_data, md_tx_offset, md_tx_size, md_tx_err;
    endclocking

    // Clocking blocks - APB
    clocking apb_cb @(posedge clk);
        default input #1step; default output #1;
        output psel, penable, pwrite, paddr, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    // Clocking blocks - IRQ
    clocking irq_cb @(posedge clk);
        default input #1step;
        input irq;
    endclocking

    // Modports
    modport rx_driver_mp  (clocking rx_driver_cb,  input clk, reset_n);
    modport rx_monitor_mp (clocking rx_monitor_cb, input clk, reset_n);
    modport tx_driver_mp  (clocking tx_driver_cb,  input clk, reset_n);
    modport tx_monitor_mp (clocking tx_monitor_cb, input clk, reset_n);
    modport apb_driver_mp (clocking apb_cb,        input clk, reset_n);
    modport apb_monitor_mp(clocking apb_cb,        input clk, reset_n);
    modport irq_mp        (clocking irq_cb,        input clk, reset_n);

    // Modport para conectar al DUT
    modport DUT (
        input  clk, reset_n,
        // MD RX
        input  md_rx_valid, md_rx_data, md_rx_offset, md_rx_size,
        output md_rx_ready, md_rx_err,
        // MD TX
        output md_tx_valid, md_tx_data, md_tx_offset, md_tx_size,
        input  md_tx_ready, md_tx_err,
        // APB
        input  psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr,
        // IRQ
        output irq
    );

    // Aserciones
    property rx_hold_when_not_ready;
        @(posedge clk) disable iff (!reset_n)
        (md_rx_valid && !md_rx_ready) |-> 
            ($stable(md_rx_data) && $stable(md_rx_offset) && $stable(md_rx_size));
    endproperty
    ast_rx_hold: assert property (rx_hold_when_not_ready)
        else $error("[IF] RX data changed while ready=0");

    // NOTA: ast_tx_offset eliminada - md_tx_offset refleja CTRL.OFFSET según spec,
    // no está obligado a ser siempre 0.

    property rx_size_not_zero;
        @(posedge clk) disable iff (!reset_n)
        md_rx_valid |-> (md_rx_size != 3'd0);
    endproperty
    ast_rx_size: assert property (rx_size_not_zero)
        else $error("[IF] md_rx_size=0 illegal");

endinterface : aligner_if
