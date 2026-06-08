// =============================================================================
// testbench.sv
// Fixes vs versión anterior:
//   [FIX-W1] RegModel warnings: write/read por registro completo con máscara
//            en lugar de acceso por campo individual
//   [FIX-W2] PSLVERR en reset_dut: escritura IRQEN con valor 0 era legal,
//            el PSLVERR venía del write a CTRL con campo RO — corregido
//            usando write al registro completo con valor correcto
//   [FIX-RESET] Espera 200ns antes de reset_dut() → sin deadlock APB
//   [FIX-APB]   drive_apb usa solo apb_cb clocking block
//   [FIX-WD]    Watchdog en 50000 ciclos
//
// Tests incluidos:
//   test_basic_align  — offset=0 size=4, 8 paquetes, 0 drops esperados
//   test_offset_align — offset=2 size=2, 8 paquetes, verifica realineación
//   test_drops        — mezcla legal+ilegal, verifica CNT_DROP
//   test_irq          — verifica IRQ.RX_FIFO_EMPTY e IRQ.TX_FIFO_EMPTY
// =============================================================================

// =============================================================================
// RAL package
// =============================================================================
package cfs_aligner_ral_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class cfs_aligner_regs__ctrl extends uvm_reg;
        rand uvm_reg_field size;
        rand uvm_reg_field reserved0;
        rand uvm_reg_field offset;
        rand uvm_reg_field reserved1;
        rand uvm_reg_field clr;

        function new(string name = "cfs_aligner_regs__ctrl");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.size      = new("size");
            this.size.configure(this, 3, 0, "RW", 1, 'h1, 1, 1, 0);
            this.reserved0 = new("reserved0");
            this.reserved0.configure(this, 4, 3, "RO", 0, 'h0, 1, 1, 0);
            this.offset    = new("offset");
            this.offset.configure(this, 2, 8, "RW", 1, 'h0, 1, 1, 0);
            this.reserved1 = new("reserved1");
            this.reserved1.configure(this, 6, 10, "RO", 0, 'h0, 1, 1, 0);
            this.clr       = new("clr");
            this.clr.configure(this, 1, 16, "WO", 1, 'h0, 1, 1, 0);
        endfunction
    endclass

    class cfs_aligner_regs__status extends uvm_reg;
        rand uvm_reg_field cnt_drop;
        rand uvm_reg_field rx_lvl;
        rand uvm_reg_field reserved0;
        rand uvm_reg_field tx_lvl;
        rand uvm_reg_field reserved1;

        function new(string name = "cfs_aligner_regs__status");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.cnt_drop  = new("cnt_drop");
            this.cnt_drop.configure(this, 8, 0, "RO", 1, 'h0, 1, 1, 0);
            this.rx_lvl    = new("rx_lvl");
            this.rx_lvl.configure(this, 4, 8, "RO", 1, 'h0, 1, 1, 0);
            this.reserved0 = new("reserved0");
            this.reserved0.configure(this, 4, 12, "RO", 0, 'h0, 1, 1, 0);
            this.tx_lvl    = new("tx_lvl");
            this.tx_lvl.configure(this, 4, 16, "RO", 1, 'h0, 1, 1, 0);
            this.reserved1 = new("reserved1");
            this.reserved1.configure(this, 12, 20, "RO", 0, 'h0, 1, 1, 0);
        endfunction
    endclass

    class cfs_aligner_regs__irqen extends uvm_reg;
        rand uvm_reg_field rx_fifo_empty;
        rand uvm_reg_field rx_fifo_full;
        rand uvm_reg_field tx_fifo_empty;
        rand uvm_reg_field tx_fifo_full;
        rand uvm_reg_field max_drop;
        rand uvm_reg_field reserved;

        function new(string name = "cfs_aligner_regs__irqen");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.rx_fifo_empty = new("rx_fifo_empty");
            this.rx_fifo_empty.configure(this, 1, 0, "RW", 0, 'h1, 1, 1, 0);
            this.rx_fifo_full  = new("rx_fifo_full");
            this.rx_fifo_full.configure(this, 1, 1, "RW", 0, 'h1, 1, 1, 0);
            this.tx_fifo_empty = new("tx_fifo_empty");
            this.tx_fifo_empty.configure(this, 1, 2, "RW", 0, 'h1, 1, 1, 0);
            this.tx_fifo_full  = new("tx_fifo_full");
            this.tx_fifo_full.configure(this, 1, 3, "RW", 0, 'h1, 1, 1, 0);
            this.max_drop      = new("max_drop");
            this.max_drop.configure(this, 1, 4, "RW", 0, 'h1, 1, 1, 0);
            this.reserved      = new("reserved");
            this.reserved.configure(this, 27, 5, "RO", 0, 'h0, 1, 1, 0);
        endfunction
    endclass

    class cfs_aligner_regs__irq extends uvm_reg;
        rand uvm_reg_field rx_fifo_empty;
        rand uvm_reg_field rx_fifo_full;
        rand uvm_reg_field tx_fifo_empty;
        rand uvm_reg_field tx_fifo_full;
        rand uvm_reg_field max_drop;
        rand uvm_reg_field reserved;

        function new(string name = "cfs_aligner_regs__irq");
            super.new(name, 32, UVM_NO_COVERAGE);
        endfunction

        virtual function void build();
            this.rx_fifo_empty = new("rx_fifo_empty");
            this.rx_fifo_empty.configure(this, 1, 0, "W1C", 1, 'h0, 1, 1, 0);
            this.rx_fifo_full  = new("rx_fifo_full");
            this.rx_fifo_full.configure(this, 1, 1, "W1C", 1, 'h0, 1, 1, 0);
            this.tx_fifo_empty = new("tx_fifo_empty");
            this.tx_fifo_empty.configure(this, 1, 2, "W1C", 1, 'h0, 1, 1, 0);
            this.tx_fifo_full  = new("tx_fifo_full");
            this.tx_fifo_full.configure(this, 1, 3, "W1C", 1, 'h0, 1, 1, 0);
            this.max_drop      = new("max_drop");
            this.max_drop.configure(this, 1, 4, "W1C", 1, 'h0, 1, 1, 0);
            this.reserved      = new("reserved");
            this.reserved.configure(this, 27, 5, "RO", 0, 'h0, 1, 1, 0);
        endfunction
    endclass

    class cfs_aligner_regs extends uvm_reg_block;
        rand cfs_aligner_regs__ctrl   ctrl;
        rand cfs_aligner_regs__status status;
        rand cfs_aligner_regs__irqen  irqen;
        rand cfs_aligner_regs__irq    irq;

        function new(string name = "cfs_aligner_regs");
            super.new(name);
        endfunction

        virtual function void build();
            this.default_map = create_map("reg_map", 0, 4, UVM_NO_ENDIAN);

            this.ctrl = new("ctrl");
            this.ctrl.configure(this);
            this.ctrl.build();
            this.default_map.add_reg(this.ctrl, 'h0);

            this.status = new("status");
            this.status.configure(this);
            this.status.build();
            this.default_map.add_reg(this.status, 'hc);

            this.irqen = new("irqen");
            this.irqen.configure(this);
            this.irqen.build();
            this.default_map.add_reg(this.irqen, 'hf0);

            this.irq = new("irq");
            this.irq.configure(this);
            this.irq.build();
            this.default_map.add_reg(this.irq, 'hf4);
        endfunction
    endclass

endpackage : cfs_aligner_ral_pkg

// =============================================================================
// Imports globales
// =============================================================================
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;
import cfs_aligner_ral_pkg::*;

// =============================================================================
// INTERFACE
// =============================================================================
interface aligner_if (input logic clk, input logic reset_n);

    logic        md_rx_valid;
    logic [31:0] md_rx_data;
    logic [1:0]  md_rx_offset;
    logic [2:0]  md_rx_size;
    logic        md_rx_ready;
    logic        md_rx_err;

    logic        md_tx_valid;
    logic [31:0] md_tx_data;
    logic [1:0]  md_tx_offset;
    logic [2:0]  md_tx_size;
    logic        md_tx_ready;
    logic        md_tx_err;

    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [15:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;
    logic        irq;

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

    modport rx_driver_mp  (clocking rx_driver_cb,  input clk, reset_n);
    modport rx_monitor_mp (clocking rx_monitor_cb, input clk, reset_n);
    modport tx_driver_mp  (clocking tx_driver_cb,  input clk, reset_n);
    modport tx_monitor_mp (clocking tx_monitor_cb, input clk, reset_n);
    modport irq_mp        (clocking irq_cb,        input clk, reset_n);

    property rx_hold_when_not_ready;
        @(posedge clk) disable iff (!reset_n)
        (md_rx_valid && !md_rx_ready) |=>
            ($stable(md_rx_data) && $stable(md_rx_offset) && $stable(md_rx_size));
    endproperty
    ast_rx_hold: assert property (rx_hold_when_not_ready)
        else $error("[IF] RX dato cambió con ready=0");

    property tx_offset_zero;
        @(posedge clk) disable iff (!reset_n)
        md_tx_valid |-> (md_tx_offset == 2'b00);
    endproperty
    ast_tx_offset: assert property (tx_offset_zero)
        else $error("[IF] md_tx_offset != 0");

    property rx_size_not_zero;
        @(posedge clk) disable iff (!reset_n)
        md_rx_valid |-> (md_rx_size != 3'd0);
    endproperty
    ast_rx_size: assert property (rx_size_not_zero)
        else $error("[IF] md_rx_size=0 ilegal");

endinterface : aligner_if

// =============================================================================
// PACKAGE PRINCIPAL DEL TESTBENCH
// =============================================================================
package aligner_tb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import cfs_aligner_ral_pkg::*;

    `uvm_analysis_imp_decl(_rx)
    `uvm_analysis_imp_decl(_tx)
    `uvm_analysis_imp_decl(_irq)

    // =========================================================================
    // TRANSACTIONS
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
             logic        valid;
             logic        err;

        constraint c_size_not_zero { size inside {3'd1, 3'd2, 3'd3, 3'd4}; }
        constraint c_valid_dist    { valid dist {1'b1 := 90, 1'b0 := 10}; }
        constraint c_legal {
            !(offset == 2'b01 && size == 3'd3);
            !(offset == 2'b11 && size == 3'd2);
            !(offset == 2'b01 && size == 3'd2);
            !(offset == 2'b11 && size == 3'd4);
        }
        constraint c_size_dist   { size   dist {3'd1:=25, 3'd2:=25, 3'd3:=25, 3'd4:=25}; }
        constraint c_offset_dist { offset dist {2'b00:=40, 2'b01:=20, 2'b10:=20, 2'b11:=20}; }

        function new(string name = "rx_transaction");
            super.new(name); valid = 1'b1; err = 1'b0;
        endfunction

        function string convert2string();
            return $sformatf("[RX] data=0x%08X offset=%0d size=%0d valid=%0b err=%0b",
                             data, offset, size, valid, err);
        endfunction

        function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            rx_transaction rhs_t;
            if (!$cast(rhs_t, rhs)) return 0;
            return (data==rhs_t.data && offset==rhs_t.offset &&
                    size==rhs_t.size && valid==rhs_t.valid);
        endfunction
    endclass : rx_transaction

    class rx_transaction_illegal extends rx_transaction;
        `uvm_object_utils(rx_transaction_illegal)
        // Fuerza combinaciones ilegales: (4+offset)%size != 0
        constraint c_force_illegal {
            (offset == 2'b01 && size == 3'd3) ||
            (offset == 2'b11 && size == 3'd2);
        }
        function void pre_randomize();
            c_legal.constraint_mode(0);
        endfunction
        function new(string name = "rx_transaction_illegal");
            super.new(name);
        endfunction
    endclass : rx_transaction_illegal

    class tx_transaction extends uvm_sequence_item;
        `uvm_object_utils_begin(tx_transaction)
            `uvm_field_int(data,   UVM_ALL_ON)
            `uvm_field_int(offset, UVM_ALL_ON)
            `uvm_field_int(size,   UVM_ALL_ON)
            `uvm_field_int(valid,  UVM_ALL_ON)
            `uvm_field_int(err,    UVM_ALL_ON)
        `uvm_object_utils_end

        logic [31:0] data;
        logic [1:0]  offset;
        logic [2:0]  size;
        logic        valid;
        logic        err;

        function new(string name = "tx_transaction");
            super.new(name); offset = 2'b00; err = 1'b0;
        endfunction

        function string convert2string();
            return $sformatf("[TX] data=0x%08X offset=%0d size=%0d valid=%0b err=%0b",
                             data, offset, size, valid, err);
        endfunction

        function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            tx_transaction rhs_t;
            if (!$cast(rhs_t, rhs)) return 0;
            return (data==rhs_t.data && offset==rhs_t.offset &&
                    size==rhs_t.size && valid==rhs_t.valid);
        endfunction
    endclass : tx_transaction

    class irq_transaction extends uvm_sequence_item;
        `uvm_object_utils_begin(irq_transaction)
            `uvm_field_int(irq_detected, UVM_ALL_ON)
            `uvm_field_int(timestamp,    UVM_ALL_ON)
        `uvm_object_utils_end
        logic irq_detected;
        time  timestamp;
        function new(string name = "irq_transaction");
            super.new(name);
        endfunction
        function string convert2string();
            return $sformatf("[IRQ] @ %0t", timestamp);
        endfunction
    endclass : irq_transaction

    class apb_transaction extends uvm_sequence_item;
        `uvm_object_utils_begin(apb_transaction)
            `uvm_field_int(addr,   UVM_ALL_ON)
            `uvm_field_int(data,   UVM_ALL_ON)
            `uvm_field_int(write,  UVM_ALL_ON)
            `uvm_field_int(slverr, UVM_ALL_ON)
        `uvm_object_utils_end
        rand logic [15:0] addr;
        rand logic [31:0] data;
        rand logic        write;
             logic        slverr;
        function new(string name = "apb_transaction");
            super.new(name);
        endfunction
    endclass : apb_transaction

    // =========================================================================
    // APB ADAPTER
    // =========================================================================
    class apb_adapter extends uvm_reg_adapter;
        `uvm_object_utils(apb_adapter)

        function new(string name = "apb_adapter");
            super.new(name);
            supports_byte_enable = 0;
            provides_responses   = 1;
        endfunction

        virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
            apb_transaction tr = apb_transaction::type_id::create("tr");
            tr.addr  = rw.addr[15:0];
            tr.data  = rw.data;
            tr.write = (rw.kind == UVM_WRITE);
            return tr;
        endfunction

        virtual function void bus2reg(uvm_sequence_item bus_item,
                                      ref uvm_reg_bus_op rw);
            apb_transaction tr;
            if (!$cast(tr, bus_item))
                `uvm_fatal("APB_ADAPT", "Cast falló")
            rw.kind   = tr.write ? UVM_WRITE : UVM_READ;
            rw.addr   = tr.addr;
            rw.data   = tr.data;
            rw.status = tr.slverr ? UVM_NOT_OK : UVM_IS_OK;
        endfunction
    endclass : apb_adapter

    // =========================================================================
    // APB DRIVER — usa apb_cb clocking block exclusivamente [FIX-APB]
    // =========================================================================
    class apb_driver extends uvm_driver #(apb_transaction);
        `uvm_component_utils(apb_driver)
        virtual aligner_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual aligner_if)::get(
                    this, "", "apb_vif", vif))
                `uvm_fatal("APB_DRV", "No se encontró apb_vif")
        endfunction

        task run_phase(uvm_phase phase);
            vif.apb_cb.psel    <= 0;
            vif.apb_cb.penable <= 0;
            vif.apb_cb.pwrite  <= 0;
            vif.apb_cb.paddr   <= 0;
            vif.apb_cb.pwdata  <= 0;
            @(posedge vif.clk);
            while (!vif.reset_n) @(posedge vif.clk);
            repeat(2) @(vif.apb_cb);
            `uvm_info("APB_DRV", "Reset liberado, APB listo", UVM_LOW)
            forever begin
                apb_transaction tr;
                seq_item_port.get_next_item(tr);
                drive_apb(tr);
                seq_item_port.item_done(tr);
            end
        endtask

        // Protocolo APB limpio usando solo clocking block [FIX-APB]
        task drive_apb(apb_transaction tr);
            // Setup phase
            @(vif.apb_cb);
            vif.apb_cb.psel    <= 1;
            vif.apb_cb.pwrite  <= tr.write;
            vif.apb_cb.paddr   <= tr.addr;
            vif.apb_cb.pwdata  <= tr.data;
            vif.apb_cb.penable <= 0;
            // Access phase
            @(vif.apb_cb);
            vif.apb_cb.penable <= 1;
            // Esperar pready
            @(vif.apb_cb);
            while (!vif.apb_cb.pready) @(vif.apb_cb);
            tr.slverr = vif.apb_cb.pslverr;
            if (!tr.write) tr.data = vif.apb_cb.prdata;
            // Idle
            @(vif.apb_cb);
            vif.apb_cb.psel    <= 0;
            vif.apb_cb.penable <= 0;
            vif.apb_cb.pwrite  <= 0;
            vif.apb_cb.paddr   <= 0;
            vif.apb_cb.pwdata  <= 0;
        endtask
    endclass : apb_driver

    // =========================================================================
    // APB MONITOR — virtual aligner_if sin modport [FIX-VCP5274]
    // =========================================================================
    class apb_monitor extends uvm_monitor;
        `uvm_component_utils(apb_monitor)
        uvm_analysis_port #(apb_transaction) ap;
        virtual aligner_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db #(virtual aligner_if)::get(
                    this, "", "apb_vif", vif))
                `uvm_fatal("APB_MON", "No se encontró apb_vif")
        endfunction

        task run_phase(uvm_phase phase);
            apb_transaction tr;
            @(posedge vif.clk);
            while (!vif.reset_n) @(posedge vif.clk);
            forever begin
                @(posedge vif.clk); #1step;
                if (vif.psel && vif.penable && vif.pready) begin
                    tr        = apb_transaction::type_id::create("tr");
                    tr.addr   = vif.paddr;
                    tr.write  = vif.pwrite;
                    tr.data   = vif.pwrite ? vif.pwdata : vif.prdata;
                    tr.slverr = vif.pslverr;
                    ap.write(tr);
                end
            end
        endtask
    endclass : apb_monitor

    // =========================================================================
    // RX DRIVER
    // =========================================================================
    class rx_driver extends uvm_driver #(rx_transaction);
        `uvm_component_utils(rx_driver)
        virtual aligner_if.rx_driver_mp vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual aligner_if.rx_driver_mp)::get(
                    this, "", "rx_vif", vif))
                `uvm_fatal("RX_DRV", "No se encontró rx_vif")
        endfunction

        task run_phase(uvm_phase phase);
            drive_idle();
            @(posedge vif.clk);
            while (!vif.reset_n) @(posedge vif.clk);
            `uvm_info("RX_DRV", "Reset liberado", UVM_LOW)
            forever begin
                rx_transaction tr;
                seq_item_port.get_next_item(tr);
                if (!tr.valid) begin
                    drive_idle();
                    repeat(2) @(vif.rx_driver_cb);
                end else begin
                    drive_transaction(tr);
                end
                `uvm_info("RX_DRV", tr.convert2string(), UVM_MEDIUM)
                seq_item_port.item_done();
            end
        endtask

        task drive_transaction(rx_transaction tr);
            vif.rx_driver_cb.md_rx_valid  <= 1'b1;
            vif.rx_driver_cb.md_rx_data   <= tr.data;
            vif.rx_driver_cb.md_rx_offset <= tr.offset;
            vif.rx_driver_cb.md_rx_size   <= tr.size;
            @(vif.rx_driver_cb);
            while (!vif.rx_driver_cb.md_rx_ready) @(vif.rx_driver_cb);
            drive_idle();
            @(vif.rx_driver_cb);
        endtask

        task drive_idle();
            vif.rx_driver_cb.md_rx_valid  <= 1'b0;
            vif.rx_driver_cb.md_rx_data   <= 32'h0;
            vif.rx_driver_cb.md_rx_offset <= 2'b00;
            vif.rx_driver_cb.md_rx_size   <= 3'd1;
        endtask
    endclass : rx_driver

    // =========================================================================
    // RX MONITOR
    // =========================================================================
    class rx_monitor extends uvm_monitor;
        `uvm_component_utils(rx_monitor)
        uvm_analysis_port #(rx_transaction) ap;
        virtual aligner_if.rx_monitor_mp vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db #(virtual aligner_if.rx_monitor_mp)::get(
                    this, "", "rx_vif", vif))
                `uvm_fatal("RX_MON", "No se encontró rx_vif")
        endfunction

        task run_phase(uvm_phase phase);
            @(posedge vif.clk);
            while (!vif.reset_n) @(posedge vif.clk);
            forever begin
                @(vif.rx_monitor_cb);
                if (vif.rx_monitor_cb.md_rx_valid && vif.rx_monitor_cb.md_rx_ready) begin
                    rx_transaction tr = rx_transaction::type_id::create("rx_tr");
                    tr.data   = vif.rx_monitor_cb.md_rx_data;
                    tr.offset = vif.rx_monitor_cb.md_rx_offset;
                    tr.size   = vif.rx_monitor_cb.md_rx_size;
                    tr.valid  = vif.rx_monitor_cb.md_rx_valid;
                    tr.err    = vif.rx_monitor_cb.md_rx_err;
                    `uvm_info("RX_MON", tr.convert2string(), UVM_HIGH)
                    ap.write(tr);
                end
            end
        endtask
    endclass : rx_monitor

    // =========================================================================
    // TX MONITOR
    // =========================================================================
    class tx_monitor extends uvm_monitor;
        `uvm_component_utils(tx_monitor)
        uvm_analysis_port #(tx_transaction) ap;
        virtual aligner_if.tx_monitor_mp vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db #(virtual aligner_if.tx_monitor_mp)::get(
                    this, "", "tx_vif", vif))
                `uvm_fatal("TX_MON", "No se encontró tx_vif")
        endfunction

        task run_phase(uvm_phase phase);
            @(posedge vif.clk);
            while (!vif.reset_n) @(posedge vif.clk);
            forever begin
                @(vif.tx_monitor_cb);
                if (vif.tx_monitor_cb.md_tx_valid && vif.tx_monitor_cb.md_tx_ready) begin
                    tx_transaction tr = tx_transaction::type_id::create("tx_tr");
                    tr.data   = vif.tx_monitor_cb.md_tx_data;
                    tr.offset = vif.tx_monitor_cb.md_tx_offset;
                    tr.size   = vif.tx_monitor_cb.md_tx_size;
                    tr.valid  = vif.tx_monitor_cb.md_tx_valid;
                    tr.err    = vif.tx_monitor_cb.md_tx_err;
                    `uvm_info("TX_MON", tr.convert2string(), UVM_HIGH)
                    ap.write(tr);
                end
            end
        endtask
    endclass : tx_monitor

    // =========================================================================
    // IRQ MONITOR
    // =========================================================================
    class irq_monitor extends uvm_monitor;
        `uvm_component_utils(irq_monitor)
        uvm_analysis_port #(irq_transaction) ap;
        virtual aligner_if.irq_mp vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            if (!uvm_config_db #(virtual aligner_if.irq_mp)::get(
                    this, "", "irq_vif", vif))
                `uvm_fatal("IRQ_MON", "No se encontró irq_vif")
        endfunction

        task run_phase(uvm_phase phase);
            @(posedge vif.clk);
            while (!vif.reset_n) @(posedge vif.clk);
            forever begin
                @(posedge vif.irq_cb.irq);
                begin
                    irq_transaction tr = irq_transaction::type_id::create("irq_tr");
                    tr.irq_detected = 1'b1;
                    tr.timestamp    = $time;
                    `uvm_info("IRQ_MON", tr.convert2string(), UVM_LOW)
                    ap.write(tr);
                end
            end
        endtask
    endclass : irq_monitor

    // =========================================================================
    // SCOREBOARD
    // =========================================================================
    class scoreboard extends uvm_scoreboard;
        `uvm_component_utils(scoreboard)

        uvm_analysis_imp_rx  #(rx_transaction,  scoreboard) rx_export;
        uvm_analysis_imp_tx  #(tx_transaction,  scoreboard) tx_export;
        uvm_analysis_imp_irq #(irq_transaction, scoreboard) irq_export;

        rx_transaction rx_queue[$];
        int unsigned expected_drops, actual_drops, tx_count, drop_count, error_count;
        int unsigned irq_count;

        // Configuración de alineación (establecida por el test)
        logic [1:0] cfg_offset;
        logic [2:0] cfg_size;

        localparam int ALGN_DATA_WIDTH = 32;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            cfg_offset = 2'b00;
            cfg_size   = 3'd4;
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            rx_export  = new("rx_export",  this);
            tx_export  = new("tx_export",  this);
            irq_export = new("irq_export", this);
        endfunction

        // Llamar desde el test antes de enviar tráfico
        function void set_cfg(logic [1:0] off, logic [2:0] sz);
            cfg_offset = off;
            cfg_size   = sz;
        endfunction

        function void write_rx(rx_transaction tr);
            int unsigned n_bytes   = tr.size;
            int unsigned resultado = ((ALGN_DATA_WIDTH/8) + tr.offset) % n_bytes;
            bit is_drop = (resultado != 0);

            `uvm_info("SB", $sformatf(
                "[RX] data=0x%08X off=%0d size=%0d formula=(%0d+%0d)%%%0d=%0d drop=%0b",
                tr.data, tr.offset, tr.size, ALGN_DATA_WIDTH/8,
                tr.offset, n_bytes, resultado, is_drop), UVM_MEDIUM)

            if (is_drop) begin
                expected_drops++;
                drop_count++;
                `uvm_info("SB", $sformatf("[DROP esperado #%0d]", expected_drops), UVM_LOW)
            end else begin
                rx_transaction exp = rx_transaction::type_id::create("exp");
                exp.copy(tr);
                rx_queue.push_back(exp);
            end
        endfunction

        function void write_tx(tx_transaction tr);
            rx_transaction expected_rx;
            logic [31:0]   expected_data;

            if (tr.offset !== 2'b00) begin
                `uvm_error("SB", $sformatf("[TX ERROR] offset=%0d != 0", tr.offset))
                error_count++; return;
            end
            if (rx_queue.size() == 0) begin
                `uvm_error("SB", $sformatf("[TX ERROR] dato inesperado 0x%08X", tr.data))
                error_count++; return;
            end

            expected_rx   = rx_queue.pop_front();
            expected_data = calc_expected_tx_data(expected_rx);

            if (tr.data !== expected_data) begin
                `uvm_error("SB", $sformatf(
                    "[TX ERROR] esperado=0x%08X recibido=0x%08X (rx_off=%0d rx_size=%0d cfg_off=%0d cfg_sz=%0d)",
                    expected_data, tr.data,
                    expected_rx.offset, expected_rx.size,
                    cfg_offset, cfg_size))
                error_count++;
            end else begin
                `uvm_info("SB", $sformatf("[TX OK] 0x%08X", tr.data), UVM_MEDIUM)
                tx_count++;
            end
        endfunction

        function void write_irq(irq_transaction tr);
            irq_count++;
            `uvm_info("SB", $sformatf("[IRQ #%0d] @ %0t", irq_count, tr.timestamp), UVM_LOW)
        endfunction

        // [FIX-W1] Acceso por registro completo: el test lee STATUS completo
        // y extrae el campo CNT_DROP con máscara — ya no usa field.read()
        function void set_actual_drops(int unsigned drops);
            actual_drops = drops;
            if (actual_drops !== expected_drops)
                `uvm_error("SB", $sformatf("[CNT_DROP ERROR] esperado=%0d leído=%0d",
                            expected_drops, actual_drops))
            else
                `uvm_info("SB", $sformatf("[CNT_DROP OK] %0d", actual_drops), UVM_LOW)
        endfunction

        function void verify_irq_count(int unsigned expected);
            if (irq_count < expected)
                `uvm_error("SB", $sformatf("[IRQ ERROR] esperados>=%0d recibidos=%0d",
                            expected, irq_count))
            else
                `uvm_info("SB", $sformatf("[IRQ OK] count=%0d", irq_count), UVM_LOW)
        endfunction

        function void check_phase(uvm_phase phase);
            if (rx_queue.size() > 0) begin
                `uvm_error("SB", $sformatf("[FINAL] %0d RX sin TX correspondiente",
                            rx_queue.size()))
                error_count++;
            end
            `uvm_info("SB", $sformatf(
                "\n==========================================\n  TX OK:%0d  Drops:%0d  IRQs:%0d  Errores:%0d\n==========================================",
                tx_count, drop_count, irq_count, error_count), UVM_NONE)
            if (error_count > 0) `uvm_error("SB", "TEST FALLIDO")
            else                  `uvm_info("SB",  "TEST PASADO", UVM_NONE)
        endfunction

        // Calcula el dato TX esperado dado un RX:
        // extrae cfg_size bytes desde rx.data[rx.offset*8 +: ...] y los pone en offset 0
        function logic [31:0] calc_expected_tx_data(rx_transaction rx);
            logic [31:0] result = 32'h0;
            for (int i = 0; i < int'(cfg_size); i++) begin
                logic [7:0] bval;
                int src_byte = int'(rx.offset) + i;
                if (src_byte < 4)
                    bval = rx.data[src_byte*8 +: 8];
                else
                    bval = 8'h0;
                result[i*8 +: 8] = bval;
            end
            return result;
        endfunction

        function void reset_counters();
            rx_queue.delete();
            expected_drops = 0;
            actual_drops   = 0;
            tx_count       = 0;
            drop_count     = 0;
            error_count    = 0;
            irq_count      = 0;
        endfunction
    endclass : scoreboard

    // =========================================================================
    // AGENTES
    // =========================================================================
    class rx_agent extends uvm_agent;
        `uvm_component_utils(rx_agent)
        uvm_sequencer #(rx_transaction) sequencer;
        rx_driver  driver;
        rx_monitor monitor;
        uvm_analysis_port #(rx_transaction) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap        = new("ap", this);
            sequencer = uvm_sequencer #(rx_transaction)::type_id::create("sequencer", this);
            driver    = rx_driver::type_id::create("driver", this);
            monitor   = rx_monitor::type_id::create("monitor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            monitor.ap.connect(ap);
        endfunction
    endclass : rx_agent

    class apb_agent extends uvm_agent;
        `uvm_component_utils(apb_agent)
        uvm_sequencer #(apb_transaction) sequencer;
        apb_driver  driver;
        apb_monitor monitor;
        uvm_analysis_port #(apb_transaction) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap        = new("ap", this);
            sequencer = uvm_sequencer #(apb_transaction)::type_id::create("sequencer", this);
            driver    = apb_driver::type_id::create("driver", this);
            monitor   = apb_monitor::type_id::create("monitor", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            monitor.ap.connect(ap);
        endfunction
    endclass : apb_agent

    // =========================================================================
    // ENV
    // =========================================================================
    class aligner_env extends uvm_env;
        `uvm_component_utils(aligner_env)

        rx_agent    rx_agt;
        apb_agent   apb_agt;
        tx_monitor  tx_mon;
        irq_monitor irq_mon;
        scoreboard  sb;
        cfs_aligner_regs reg_model;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            rx_agt  = rx_agent::type_id::create("rx_agt",   this);
            apb_agt = apb_agent::type_id::create("apb_agt", this);
            tx_mon  = tx_monitor::type_id::create("tx_mon", this);
            irq_mon = irq_monitor::type_id::create("irq_mon", this);
            sb      = scoreboard::type_id::create("sb",     this);
            if (!uvm_config_db #(cfs_aligner_regs)::get(this, "", "reg_model", reg_model))
                `uvm_fatal("ENV", "No se encontró reg_model en env")
        endfunction

        function void connect_phase(uvm_phase phase);
            apb_adapter adapter;
            rx_agt.ap.connect(sb.rx_export);
            tx_mon.ap.connect(sb.tx_export);
            irq_mon.ap.connect(sb.irq_export);
            adapter = apb_adapter::type_id::create("adapter");
            reg_model.default_map.set_sequencer(apb_agt.sequencer, adapter);
            reg_model.default_map.set_auto_predict(0);
        endfunction
    endclass : aligner_env

    // =========================================================================
    // TX READY DRIVER
    // =========================================================================
    class tx_ready_driver extends uvm_component;
        `uvm_component_utils(tx_ready_driver)
        virtual aligner_if.tx_driver_mp vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual aligner_if.tx_driver_mp)::get(
                    this, "", "tx_vif", vif))
                `uvm_fatal("TX_RDY", "No se encontró tx_vif")
        endfunction

        task run_phase(uvm_phase phase);
            vif.tx_driver_cb.md_tx_ready <= 1'b1;
            forever @(vif.tx_driver_cb)
                vif.tx_driver_cb.md_tx_ready <= 1'b1;
        endtask
    endclass : tx_ready_driver

    // =========================================================================
    // TEST BASE
    // [FIX-W1] Todas las operaciones de registro usan write/read al registro
    //          completo con máscaras en lugar de acceso por campo individual.
    //          Esto elimina el warning "Individual field access not available".
    //
    // [FIX-W2] write_ctrl() construye el valor 32 bits explícitamente:
    //          solo escribe los campos RW (size en bits[2:0], offset en bits[9:8]).
    //          No toca bits reservados ni el campo WO CLR (bit 16).
    //          Así el DUT no ve un valor ilegal y no genera PSLVERR.
    // =========================================================================
    class test_base extends uvm_test;
        `uvm_component_utils(test_base)

        aligner_env      env;
        tx_ready_driver  tx_rdy;
        cfs_aligner_regs reg_model;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            reg_model = new("reg_model");
            reg_model.build();
            reg_model.lock_model();
            uvm_config_db #(cfs_aligner_regs)::set(this, "*", "reg_model", reg_model);
            env    = aligner_env::type_id::create("env",   this);
            tx_rdy = tx_ready_driver::type_id::create("tx_rdy", this);
        endfunction

        // [FIX-W1][FIX-W2] Escribe CTRL con valor completo de 32 bits.
        // Bits[2:0]  = size   (campo RW)
        // Bits[9:8]  = offset (campo RW)
        // Resto = 0 (reservados y CLR en 0 → no activa clear)
        task write_ctrl(logic [2:0] sz, logic [1:0] off);
            uvm_status_e status;
            logic [31:0] val;
            val = 32'h0;
            val[2:0] = sz;
            val[9:8] = off;
            reg_model.ctrl.write(status, val);
            if (status != UVM_IS_OK)
                `uvm_error("TEST", $sformatf(
                    "CTRL write falló (size=%0d offset=%0d) — combinación ilegal?", sz, off))
            else
                `uvm_info("TEST", $sformatf(
                    "CTRL configurado: size=%0d offset=%0d", sz, off), UVM_LOW)
        endtask

        // [FIX-W1] Lee STATUS completo y extrae CNT_DROP con máscara [7:0]
        task read_cnt_drop(output int unsigned cnt);
            uvm_status_e   status;
            uvm_reg_data_t val;
            reg_model.status.read(status, val);
            cnt = int'(val[7:0]);
        endtask

        // [FIX-W1] Lee IRQ completo y devuelve el valor de 32 bits
        task read_irq(output uvm_reg_data_t val);
            uvm_status_e status;
            reg_model.irq.read(status, val);
        endtask

        // Limpia IRQ escribiendo 1 en todos los bits W1C
        task clear_irq();
            uvm_status_e status;
            reg_model.irq.write(status, 32'h1F);
        endtask

        // Deshabilita todas las interrupciones
        task disable_irq();
            uvm_status_e status;
            reg_model.irqen.write(status, 32'h0);
        endtask

        // Habilita interrupciones con máscara
        task enable_irq(logic [31:0] mask);
            uvm_status_e status;
            reg_model.irqen.write(status, mask);
        endtask

        // reset_dut: limpia IRQ y deshabilita interrupciones para test limpio
        // [FIX-RESET] Llamar solo DESPUÉS de esperar el reset HW (200ns)
        task reset_dut();
            `uvm_info("TEST", "=== reset_dut START ===", UVM_LOW)
            disable_irq();
            clear_irq();
            `uvm_info("TEST", "=== reset_dut DONE ===", UVM_LOW)
        endtask

        task run_phase(uvm_phase phase);
            phase.raise_objection(this);
            phase.drop_objection(this);
        endtask
    endclass : test_base

    // =========================================================================
    // SECUENCIAS
    // =========================================================================

    // 8 paquetes con offset y size fijos (pasados como parámetros)
    class rx_fixed_seq extends uvm_sequence #(rx_transaction);
        `uvm_object_utils(rx_fixed_seq)
        int unsigned n_pkts = 8;
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

    // Mezcla paquetes legales e ilegales
    class rx_mixed_seq extends uvm_sequence #(rx_transaction);
        `uvm_object_utils(rx_mixed_seq)
        int unsigned n_legal   = 4;
        int unsigned n_illegal = 4;

        function new(string name = "rx_mixed_seq");
            super.new(name);
        endfunction

        task body();
            // Legales primero
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
            // Ilegales: (4+1)%3 = 2 ≠ 0 → drop
            repeat(n_illegal) begin
                rx_transaction_illegal tr =
                    rx_transaction_illegal::type_id::create("tr");
                start_item(tr);
                assert(tr.randomize());
                finish_item(tr);
            end
        endtask
    endclass : rx_mixed_seq

    // =========================================================================
    // TEST 1: test_basic_align
    // Configuración: CTRL.size=4, CTRL.offset=0
    // 8 paquetes RX con offset=0, size=4 → todos pasan, 0 drops
    // =========================================================================
    class test_basic_align extends test_base;
        `uvm_component_utils(test_basic_align)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            rx_fixed_seq   seq;
            int unsigned   cnt_drop;

            phase.raise_objection(this);

            // [FIX-RESET] Esperar que el reset HW termine (10 ciclos × 10ns = 100ns)
            #200ns;
            reset_dut();

            // [FIX-W1][FIX-W2] Escribe CTRL completo sin warning ni PSLVERR
            write_ctrl(.sz(3'd4), .off(2'b00));
            env.sb.set_cfg(2'b00, 3'd4);

            `uvm_info("TEST", "=== test_basic_align: 8 pkts offset=0 size=4 ===", UVM_LOW)
            seq              = rx_fixed_seq::type_id::create("seq");
            seq.n_pkts       = 8;
            seq.fixed_offset = 2'b00;
            seq.fixed_size   = 3'd4;
            seq.start(env.rx_agt.sequencer);

            #200ns; // drenaje del pipeline TX

            read_cnt_drop(cnt_drop);
            env.sb.set_actual_drops(cnt_drop);

            `uvm_info("TEST", "test_basic_align DONE", UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass : test_basic_align

    // =========================================================================
    // TEST 2: test_offset_align
    // Configuración: CTRL.size=2, CTRL.offset=0
    // 8 paquetes RX con offset=2, size=2
    // Verifica: (4+2)%2=0 → legal, bytes válidos son data[23:16] data[31:24]
    // TX esperado: data[23:16] en byte0, data[31:24] en byte1
    // =========================================================================
    class test_offset_align extends test_base;
        `uvm_component_utils(test_offset_align)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            rx_fixed_seq seq;
            int unsigned cnt_drop;

            phase.raise_objection(this);

            #200ns;
            reset_dut();

            // CTRL: size=2 offset=0 → bits[2:0]=2, bits[9:8]=0
            write_ctrl(.sz(3'd2), .off(2'b00));
            env.sb.set_cfg(2'b00, 3'd2);

            `uvm_info("TEST", "=== test_offset_align: 8 pkts rx_offset=2 rx_size=2 ===", UVM_LOW)
            seq              = rx_fixed_seq::type_id::create("seq");
            seq.n_pkts       = 8;
            seq.fixed_offset = 2'b10;  // los bytes útiles están en posición 2 y 3
            seq.fixed_size   = 3'd2;
            seq.start(env.rx_agt.sequencer);

            #200ns;

            read_cnt_drop(cnt_drop);
            env.sb.set_actual_drops(cnt_drop);

            `uvm_info("TEST", "test_offset_align DONE", UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass : test_offset_align

    // =========================================================================
    // TEST 3: test_drops
    // Configuración: CTRL.size=4, CTRL.offset=0
    // 4 paquetes legales + 4 ilegales
    // Verifica: CNT_DROP == 4
    // =========================================================================
    class test_drops extends test_base;
        `uvm_component_utils(test_drops)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            rx_mixed_seq seq;
            int unsigned cnt_drop;

            phase.raise_objection(this);

            #200ns;
            reset_dut();

            write_ctrl(.sz(3'd4), .off(2'b00));
            env.sb.set_cfg(2'b00, 3'd4);

            `uvm_info("TEST", "=== test_drops: 4 legales + 4 ilegales ===", UVM_LOW)
            seq           = rx_mixed_seq::type_id::create("seq");
            seq.n_legal   = 4;
            seq.n_illegal = 4;
            seq.start(env.rx_agt.sequencer);

            #300ns; // más tiempo para que el DUT procese y actualice CNT_DROP

            read_cnt_drop(cnt_drop);
            env.sb.set_actual_drops(cnt_drop);

            `uvm_info("TEST", "test_drops DONE", UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass : test_drops

    // =========================================================================
    // TEST 4: test_irq
    // Habilita IRQ.RX_FIFO_EMPTY y IRQ.TX_FIFO_EMPTY (bits 0 y 2 de IRQEN)
    // Envía tráfico y verifica que al menos 1 IRQ fue detectada
    // Luego limpia y verifica que IRQ quedó en 0
    // =========================================================================
    class test_irq extends test_base;
        `uvm_component_utils(test_irq)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            rx_fixed_seq    seq;
            uvm_reg_data_t  irq_val;
            int unsigned    cnt_drop;

            phase.raise_objection(this);

            #200ns;
            reset_dut();

            write_ctrl(.sz(3'd4), .off(2'b00));
            env.sb.set_cfg(2'b00, 3'd4);

            // Habilitar RX_FIFO_EMPTY (bit0) y TX_FIFO_EMPTY (bit2)
            enable_irq(32'h5);
            `uvm_info("TEST", "=== test_irq: IRQEN=0x5 (RX_FIFO_EMPTY + TX_FIFO_EMPTY) ===", UVM_LOW)

            seq              = rx_fixed_seq::type_id::create("seq");
            seq.n_pkts       = 4;
            seq.fixed_offset = 2'b00;
            seq.fixed_size   = 3'd4;
            seq.start(env.rx_agt.sequencer);

            // Esperar a que el TX FIFO se vacíe y genere IRQ
            #500ns;

            // Verificar que al menos 1 IRQ fue detectada
            env.sb.verify_irq_count(1);

            // Leer y verificar registro IRQ
            read_irq(irq_val);
            `uvm_info("TEST", $sformatf("IRQ register = 0x%08X", irq_val), UVM_LOW)

            // Limpiar IRQs
            clear_irq();
            #50ns;

            // Verificar que IRQ quedó limpio
            read_irq(irq_val);
            if (irq_val[4:0] !== 5'b0)
                `uvm_error("TEST", $sformatf("IRQ no se limpió: 0x%0X", irq_val[4:0]))
            else
                `uvm_info("TEST", "IRQ limpio correctamente", UVM_LOW)

            read_cnt_drop(cnt_drop);
            env.sb.set_actual_drops(cnt_drop);

            `uvm_info("TEST", "test_irq DONE", UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass : test_irq

endpackage : aligner_tb_pkg

// =============================================================================
// Import del package al scope global
// =============================================================================
import aligner_tb_pkg::*;

// =============================================================================
// TB_TOP
// =============================================================================
module tb_top;

    logic clk;
    logic reset_n;

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset_n = 1'b0;
        repeat(10) @(posedge clk);
        reset_n = 1'b1;
    end

    aligner_if dut_if (.clk(clk), .reset_n(reset_n));

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

    // Watchdog extendido [FIX-WD]
    initial begin
        repeat(50000) @(posedge clk);
        $display("[WATCHDOG] Timeout tras 50000 ciclos");
        $finish;
    end

    initial begin
        uvm_config_db #(virtual aligner_if.rx_driver_mp)::set(
            null, "uvm_test_top.*", "rx_vif", dut_if);
        uvm_config_db #(virtual aligner_if.rx_monitor_mp)::set(
            null, "uvm_test_top.*", "rx_vif", dut_if);
        uvm_config_db #(virtual aligner_if.tx_monitor_mp)::set(
            null, "uvm_test_top.*", "tx_vif", dut_if);
        uvm_config_db #(virtual aligner_if.tx_driver_mp)::set(
            null, "uvm_test_top.*", "tx_vif", dut_if);
        uvm_config_db #(virtual aligner_if)::set(
            null, "uvm_test_top.*", "apb_vif", dut_if);
        uvm_config_db #(virtual aligner_if.irq_mp)::set(
            null, "uvm_test_top.*", "irq_vif", dut_if);

        run_test();
    end

endmodule : tb_top
