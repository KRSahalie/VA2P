// interfaces/apb_if.sv
`ifndef APB_IF_SV
`define APB_IF_SV

interface apb_if (
    input logic pclk,
    input logic preset_n
);
    
    // Señales APB
    logic [15:0] paddr;
    logic        pwrite;
    logic        psel;
    logic        penable;
    logic [31:0] pwdata;
    logic        pready;
    logic [31:0] prdata;
    logic        pslverr;
    
    // Clocking block para driver
    clocking drv_cb @(posedge pclk);
        default input #1ns output #1ns;
        output paddr, pwrite, psel, penable, pwdata;
        input pready, prdata, pslverr;
    endclocking
    
    // Clocking block para monitor
    clocking mon_cb @(posedge pclk);
        default input #1ns;
        input paddr, pwrite, psel, penable, pwdata, pready, prdata, pslverr;
    endclocking
    
    // Modports
    modport DRV (clocking drv_cb);
    modport MON (clocking mon_cb);
    
    // Conexión al DUT
    modport DUT (
        input  pclk, preset_n,
        output paddr, pwrite, psel, penable, pwdata,
        input  pready, prdata, pslverr
    );
    
endinterface

`endif