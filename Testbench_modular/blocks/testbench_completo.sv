// =============================================================================
// testbench_completo.sv  —  Riviera-PRO + UVM 1.2
// Run options: +UVM_TESTNAME=test_basic_align
// =============================================================================
`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

// =============================================================================
// RAL package
// =============================================================================
package cfs_aligner_ral_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;

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
      size     = new("size");     size.configure(this,3,0,"RW",1,'h1,1,1,0);
      reserved0= new("reserved0");reserved0.configure(this,4,3,"RO",0,'h0,1,1,0);
      offset   = new("offset");   offset.configure(this,2,8,"RW",1,'h0,1,1,0);
      reserved1= new("reserved1");reserved1.configure(this,6,10,"RO",0,'h0,1,1,0);
      clr      = new("clr");      clr.configure(this,1,16,"WO",1,'h0,1,1,0);
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
      cnt_drop = new("cnt_drop"); cnt_drop.configure(this,8,0,"RO",1,'h0,1,1,0);
      rx_lvl   = new("rx_lvl");   rx_lvl.configure(this,4,8,"RO",1,'h0,1,1,0);
      reserved0= new("reserved0");reserved0.configure(this,4,12,"RO",0,'h0,1,1,0);
      tx_lvl   = new("tx_lvl");   tx_lvl.configure(this,4,16,"RO",1,'h0,1,1,0);
      reserved1= new("reserved1");reserved1.configure(this,12,20,"RO",0,'h0,1,1,0);
    endfunction
  endclass

  class cfs_aligner_regs__irqen extends uvm_reg;
    rand uvm_reg_field rx_fifo_empty, rx_fifo_full, tx_fifo_empty, tx_fifo_full, max_drop, reserved;
    function new(string name = "cfs_aligner_regs__irqen");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      rx_fifo_empty=new("rx_fifo_empty"); rx_fifo_empty.configure(this,1,0,"RW",0,'h1,1,1,0);
      rx_fifo_full =new("rx_fifo_full");  rx_fifo_full.configure(this,1,1,"RW",0,'h1,1,1,0);
      tx_fifo_empty=new("tx_fifo_empty"); tx_fifo_empty.configure(this,1,2,"RW",0,'h1,1,1,0);
      tx_fifo_full =new("tx_fifo_full");  tx_fifo_full.configure(this,1,3,"RW",0,'h1,1,1,0);
      max_drop     =new("max_drop");      max_drop.configure(this,1,4,"RW",0,'h1,1,1,0);
      reserved     =new("reserved");      reserved.configure(this,27,5,"RO",0,'h0,1,1,0);
    endfunction
  endclass

  class cfs_aligner_regs__irq extends uvm_reg;
    rand uvm_reg_field rx_fifo_empty, rx_fifo_full, tx_fifo_empty, tx_fifo_full, max_drop, reserved;
    function new(string name = "cfs_aligner_regs__irq");
      super.new(name, 32, UVM_NO_COVERAGE);
    endfunction
    virtual function void build();
      rx_fifo_empty=new("rx_fifo_empty"); rx_fifo_empty.configure(this,1,0,"W1C",1,'h0,1,1,0);
      rx_fifo_full =new("rx_fifo_full");  rx_fifo_full.configure(this,1,1,"W1C",1,'h0,1,1,0);
      tx_fifo_empty=new("tx_fifo_empty"); tx_fifo_empty.configure(this,1,2,"W1C",1,'h0,1,1,0);
      tx_fifo_full =new("tx_fifo_full");  tx_fifo_full.configure(this,1,3,"W1C",1,'h0,1,1,0);
      max_drop     =new("max_drop");      max_drop.configure(this,1,4,"W1C",1,'h0,1,1,0);
      reserved     =new("reserved");      reserved.configure(this,27,5,"RO",0,'h0,1,1,0);
    endfunction
  endclass

  class cfs_aligner_regs extends uvm_reg_block;
    rand cfs_aligner_regs__ctrl   ctrl;
    rand cfs_aligner_regs__status status;
    rand cfs_aligner_regs__irqen  irqen;
    rand cfs_aligner_regs__irq    irq;
    function new(string name = "cfs_aligner_regs"); super.new(name); endfunction
    virtual function void build();
      default_map = create_map("reg_map", 0, 4, UVM_NO_ENDIAN);
      ctrl   = new("ctrl");   ctrl.configure(this);   ctrl.build();   default_map.add_reg(ctrl,   'h0);
      status = new("status"); status.configure(this); status.build(); default_map.add_reg(status, 'hc);
      irqen  = new("irqen");  irqen.configure(this);  irqen.build();  default_map.add_reg(irqen,  'hf0);
      irq    = new("irq");    irq.configure(this);    irq.build();    default_map.add_reg(irq,    'hf4);
    endfunction
  endclass

endpackage : cfs_aligner_ral_pkg

// =============================================================================
// TB package  — todo el UVM TB aqui dentro resuelve los VCP2852
// =============================================================================
package aligner_tb_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import cfs_aligner_ral_pkg::*;

  // ===========================================================================
  // TRANSACTIONS
  // ===========================================================================
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
    constraint c_size_not_zero  { size inside {3'd1,3'd2,3'd3,3'd4}; }
    constraint c_legal {
      !(offset==2'b01 && size==3'd3);
      !(offset==2'b11 && size==3'd2);
      !(offset==2'b01 && size==3'd2);
      !(offset==2'b11 && size==3'd4);
    }
    constraint c_size_dist   { size   dist {3'd1:=25,3'd2:=25,3'd3:=25,3'd4:=25}; }
    constraint c_offset_dist { offset dist {2'b00:=40,2'b01:=20,2'b10:=20,2'b11:=20}; }
    function new(string name="rx_transaction"); super.new(name); valid=1'b1; err=1'b0; endfunction
    function string convert2string();
      return $sformatf("[RX] data=0x%08X offset=%0d size=%0d valid=%0b err=%0b",data,offset,size,valid,err);
    endfunction
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
      rx_transaction rhs_t;
      if(!$cast(rhs_t,rhs)) return 0;
      return (data==rhs_t.data && offset==rhs_t.offset && size==rhs_t.size && valid==rhs_t.valid);
    endfunction
  endclass : rx_transaction

  // Illegal: disable c_legal in body, not in constraint block
  class rx_transaction_illegal extends rx_transaction;
    `uvm_object_utils(rx_transaction_illegal)
    function new(string name="rx_transaction_illegal"); super.new(name); endfunction
    // constraint_mode called from sequence body, not here
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
    function new(string name="tx_transaction"); super.new(name); offset=2'b00; err=1'b0; endfunction
    function string convert2string();
      return $sformatf("[TX] data=0x%08X offset=%0d size=%0d valid=%0b err=%0b",data,offset,size,valid,err);
    endfunction
  endclass : tx_transaction

  class irq_transaction extends uvm_sequence_item;
    `uvm_object_utils_begin(irq_transaction)
      `uvm_field_int(irq_detected, UVM_ALL_ON)
      `uvm_field_int(timestamp,    UVM_ALL_ON)
    `uvm_object_utils_end
    logic irq_detected;
    time  timestamp;
    function new(string name="irq_transaction"); super.new(name); endfunction
    function string convert2string(); return $sformatf("[IRQ] @ %0t",timestamp); endfunction
  endclass : irq_transaction

  class apb_transaction extends uvm_sequence_item;
    `uvm_object_utils_begin(apb_transaction)
      `uvm_field_int(addr,  UVM_ALL_ON)
      `uvm_field_int(data,  UVM_ALL_ON)
      `uvm_field_int(write, UVM_ALL_ON)
      `uvm_field_int(slverr,UVM_ALL_ON)
    `uvm_object_utils_end
    rand logic [15:0] addr;
    rand logic [31:0] data;
    rand logic        write;
         logic        slverr;
    function new(string name="apb_transaction"); super.new(name); endfunction
  endclass : apb_transaction

  // ===========================================================================
  // APB ADAPTER
  // ===========================================================================
  class apb_adapter extends uvm_reg_adapter;
    `uvm_object_utils(apb_adapter)
    function new(string name="apb_adapter");
      super.new(name); supports_byte_enable=0; provides_responses=1;
    endfunction
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
      apb_transaction tr;
      tr = new("tr");
      tr.addr  = rw.addr[15:0];
      tr.data  = rw.data;
      tr.write = (rw.kind == UVM_WRITE);
      return tr;
    endfunction
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
      apb_transaction tr;
      if(!$cast(tr,bus_item)) `uvm_fatal("APB_ADAPT","Cast fallo")
      rw.kind   = tr.write ? UVM_WRITE : UVM_READ;
      rw.addr   = tr.addr;
      rw.data   = tr.data;
      rw.status = tr.slverr ? UVM_NOT_OK : UVM_IS_OK;
    endfunction
  endclass : apb_adapter

  // ===========================================================================
  // SEQUENCES  (antes de drivers/monitors que las usan por nombre)
  // ===========================================================================
  class rx_basic_sequence extends uvm_sequence #(rx_transaction);
    `uvm_object_utils(rx_basic_sequence)
    function new(string name="rx_basic_sequence"); super.new(name); endfunction
    task body();
      rx_transaction tr;
      repeat(8) begin
        tr = new("tr");
        start_item(tr);
        assert(tr.randomize() with { valid==1'b1; offset==2'b00; size==3'd4; });
        finish_item(tr);
      end
    endtask
  endclass : rx_basic_sequence

  class rx_illegal_sequence extends uvm_sequence #(rx_transaction);
    `uvm_object_utils(rx_illegal_sequence)
    function new(string name="rx_illegal_sequence"); super.new(name); endfunction
    task body();
      rx_transaction_illegal tr;
      repeat(4) begin
        tr = new("tr");
        start_item(tr);
        // Disable c_legal here, force illegal combo
        tr.c_legal.constraint_mode(0);
        assert(tr.randomize() with {
          (offset==2'b01 && size==3'd3) || (offset==2'b11 && size==3'd2);
        });
        finish_item(tr);
      end
    endtask
  endclass : rx_illegal_sequence

  // ===========================================================================
  // SCOREBOARD
  // ===========================================================================
  `uvm_analysis_imp_decl(_rx)
  `uvm_analysis_imp_decl(_tx)
  `uvm_analysis_imp_decl(_irq)

  class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)
    uvm_analysis_imp_rx  #(rx_transaction,  scoreboard) rx_export;
    uvm_analysis_imp_tx  #(tx_transaction,  scoreboard) tx_export;
    uvm_analysis_imp_irq #(irq_transaction, scoreboard) irq_export;

    rx_transaction rx_queue[$];
    int unsigned expected_drops, actual_drops, tx_count, drop_count, error_count;
    localparam int ALGN_DATA_WIDTH = 32;

    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      rx_export  = new("rx_export",  this);
      tx_export  = new("tx_export",  this);
      irq_export = new("irq_export", this);
    endfunction

    function void write_rx(rx_transaction tr);
      rx_transaction exp_tr;
      int unsigned n_bytes   = tr.size;
      int unsigned resultado = ((ALGN_DATA_WIDTH/8) + tr.offset) % n_bytes;
      bit is_drop = (resultado != 0);
      `uvm_info("SB",$sformatf("[RX] data=0x%08X off=%0d size=%0d drop=%0b",tr.data,tr.offset,tr.size,is_drop),UVM_MEDIUM)
      if(is_drop) begin
        expected_drops++; drop_count++;
      end else begin
        exp_tr = new("exp_tr"); exp_tr.copy(tr); rx_queue.push_back(exp_tr);
      end
    endfunction

    function void write_tx(tx_transaction tr);
      rx_transaction expected_rx;
      logic [31:0]   expected_data;
      if(tr.offset !== 2'b00) begin
        `uvm_error("SB",$sformatf("[TX ERROR] offset=%0d != 0",tr.offset))
        error_count++; return;
      end
      if(rx_queue.size()==0) begin
        `uvm_error("SB",$sformatf("[TX ERROR] dato inesperado 0x%08X",tr.data))
        error_count++; return;
      end
      expected_rx   = rx_queue.pop_front();
      expected_data = calc_expected_tx_data(expected_rx);
      if(tr.data !== expected_data) begin
        `uvm_error("SB",$sformatf("[TX ERROR] esperado=0x%08X recibido=0x%08X",expected_data,tr.data))
        error_count++;
      end else begin
        `uvm_info("SB",$sformatf("[TX OK] 0x%08X",tr.data),UVM_MEDIUM)
        tx_count++;
      end
    endfunction

    function void write_irq(irq_transaction tr);
      `uvm_info("SB",$sformatf("[IRQ] @ %0t",tr.timestamp),UVM_LOW)
    endfunction

    function logic [31:0] calc_expected_tx_data(rx_transaction rx);
      logic [31:0] result;
      result = 32'h0;
      for(int i=0; i<rx.size; i++) begin
        logic [7:0] bval;
        bval = rx.data[(rx.offset+i)*8 +: 8];
        result[i*8 +: 8] = bval;
      end
      return result;
    endfunction

    function void set_actual_drops(int unsigned drops);
      actual_drops = drops;
      if(actual_drops !== expected_drops)
        `uvm_error("SB",$sformatf("[CNT_DROP ERROR] esperado=%0d leido=%0d",expected_drops,actual_drops))
      else
        `uvm_info("SB",$sformatf("[CNT_DROP OK] %0d",actual_drops),UVM_LOW)
    endfunction

    function void check_phase(uvm_phase phase);
      if(rx_queue.size()>0) begin
        `uvm_error("SB",$sformatf("[FINAL] %0d RX sin TX",rx_queue.size()))
        error_count++;
      end
      `uvm_info("SB",$sformatf("\n==========================================\n  TX OK:%0d  Drops:%0d  Errores:%0d\n==========================================",tx_count,drop_count,error_count),UVM_NONE)
      if(error_count>0) `uvm_error("SB","TEST FALLIDO")
      else              `uvm_info("SB","TEST PASADO",UVM_NONE)
    endfunction
  endclass : scoreboard

endpackage : aligner_tb_pkg

// =============================================================================
// INTERFACE  (fuera de package, necesita ver los modports)
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
  logic        psel, penable, pwrite;
  logic [15:0] paddr;
  logic [31:0] pwdata, prdata;
  logic        pready, pslverr, irq;

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
  modport apb_mp        (clocking apb_cb,        input clk, reset_n);
  modport irq_mp        (clocking irq_cb,        input clk, reset_n);

  property rx_hold;
    @(posedge clk) disable iff (!reset_n)
    (md_rx_valid && !md_rx_ready) |=> ($stable(md_rx_data) && $stable(md_rx_offset) && $stable(md_rx_size));
  endproperty
  ast_rx_hold: assert property(rx_hold) else $error("[IF] RX dato cambio con ready=0");

  property tx_off_zero;
    @(posedge clk) disable iff (!reset_n) md_tx_valid |-> (md_tx_offset==2'b00);
  endproperty
  ast_tx_offset: assert property(tx_off_zero) else $error("[IF] md_tx_offset != 0");

  property rx_sz_nz;
    @(posedge clk) disable iff (!reset_n) md_rx_valid |-> (md_rx_size!=3'd0);
  endproperty
  ast_rx_size: assert property(rx_sz_nz) else $error("[IF] md_rx_size=0 ilegal");
endinterface : aligner_if

// =============================================================================
// Segundo package: componentes UVM que necesitan la interface
// =============================================================================
package aligner_comp_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import cfs_aligner_ral_pkg::*;
  import aligner_tb_pkg::*;

  // ===========================================================================
  // APB DRIVER
  // ===========================================================================
  class apb_driver extends uvm_driver #(apb_transaction);
    `uvm_component_utils(apb_driver)
    virtual aligner_if.apb_mp vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual aligner_if.apb_mp)::get(this,"","apb_vif",vif))
        `uvm_fatal("APB_DRV","No apb_vif")
    endfunction
    task run_phase(uvm_phase phase);
      apb_transaction tr;
      vif.apb_cb.psel<=0; vif.apb_cb.penable<=0;
      vif.apb_cb.pwrite<=0; vif.apb_cb.paddr<=0; vif.apb_cb.pwdata<=0;
      @(posedge vif.clk); while(!vif.reset_n) @(posedge vif.clk);
      forever begin
        seq_item_port.get_next_item(tr); drive_apb(tr); seq_item_port.item_done();
      end
    endtask
    task drive_apb(apb_transaction tr);
      @(vif.apb_cb);
      vif.apb_cb.psel<=1; vif.apb_cb.pwrite<=tr.write;
      vif.apb_cb.paddr<=tr.addr; vif.apb_cb.pwdata<=tr.data;
      @(vif.apb_cb); vif.apb_cb.penable<=1;
      @(vif.apb_cb); while(!vif.apb_cb.pready) @(vif.apb_cb);
      tr.slverr = vif.apb_cb.pslverr;
      if(!tr.write) tr.data = vif.apb_cb.prdata;
      vif.apb_cb.psel<=0; vif.apb_cb.penable<=0;
      @(vif.apb_cb);
    endtask
  endclass : apb_driver

  // ===========================================================================
  // APB MONITOR
  // ===========================================================================
  class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)
    uvm_analysis_port #(apb_transaction) ap;
    virtual aligner_if.apb_mp vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); ap = new("ap",this);
      if(!uvm_config_db#(virtual aligner_if.apb_mp)::get(this,"","apb_vif",vif))
        `uvm_fatal("APB_MON","No apb_vif")
    endfunction
    task run_phase(uvm_phase phase);
      apb_transaction tr;
      @(posedge vif.clk); while(!vif.reset_n) @(posedge vif.clk);
      forever begin
        @(vif.apb_cb);
        if(vif.apb_cb.psel && vif.apb_cb.penable && vif.apb_cb.pready) begin
          tr=new("tr");
          tr.addr  = vif.apb_cb.paddr;
          tr.write = vif.apb_cb.pwrite;
          tr.data  = vif.apb_cb.pwrite ? vif.apb_cb.pwdata : vif.apb_cb.prdata;
          tr.slverr= vif.apb_cb.pslverr;
          ap.write(tr);
        end
      end
    endtask
  endclass : apb_monitor

  // ===========================================================================
  // RX DRIVER
  // ===========================================================================
  class rx_driver extends uvm_driver #(rx_transaction);
    `uvm_component_utils(rx_driver)
    virtual aligner_if.rx_driver_mp vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual aligner_if.rx_driver_mp)::get(this,"","rx_vif",vif))
        `uvm_fatal("RX_DRV","No rx_vif")
    endfunction
    task run_phase(uvm_phase phase);
      rx_transaction tr;
      drive_idle();
      @(posedge vif.clk); while(!vif.reset_n) @(posedge vif.clk);
      `uvm_info("RX_DRV","Reset liberado",UVM_LOW)
      forever begin
        seq_item_port.get_next_item(tr);
        if(!tr.valid) begin drive_idle(); repeat(2) @(vif.rx_driver_cb); end
        else          drive_transaction(tr);
        seq_item_port.item_done();
      end
    endtask
    task drive_transaction(rx_transaction tr);
      vif.rx_driver_cb.md_rx_valid <=1'b1;
      vif.rx_driver_cb.md_rx_data  <=tr.data;
      vif.rx_driver_cb.md_rx_offset<=tr.offset;
      vif.rx_driver_cb.md_rx_size  <=tr.size;
      @(vif.rx_driver_cb);
      while(!vif.rx_driver_cb.md_rx_ready) @(vif.rx_driver_cb);
      drive_idle(); @(vif.rx_driver_cb);
    endtask
    task drive_idle();
      vif.rx_driver_cb.md_rx_valid <=1'b0;
      vif.rx_driver_cb.md_rx_data  <=32'h0;
      vif.rx_driver_cb.md_rx_offset<=2'b00;
      vif.rx_driver_cb.md_rx_size  <=3'd1;
    endtask
  endclass : rx_driver

  // ===========================================================================
  // RX MONITOR
  // ===========================================================================
  class rx_monitor extends uvm_monitor;
    `uvm_component_utils(rx_monitor)
    uvm_analysis_port #(rx_transaction) ap;
    virtual aligner_if.rx_monitor_mp vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); ap=new("ap",this);
      if(!uvm_config_db#(virtual aligner_if.rx_monitor_mp)::get(this,"","rx_vif",vif))
        `uvm_fatal("RX_MON","No rx_vif")
    endfunction
    task run_phase(uvm_phase phase);
      rx_transaction tr;
      @(posedge vif.clk); while(!vif.reset_n) @(posedge vif.clk);
      forever begin
        @(vif.rx_monitor_cb);
        if(vif.rx_monitor_cb.md_rx_valid && vif.rx_monitor_cb.md_rx_ready) begin
          tr=new("rx_tr");
          tr.data  =vif.rx_monitor_cb.md_rx_data;
          tr.offset=vif.rx_monitor_cb.md_rx_offset;
          tr.size  =vif.rx_monitor_cb.md_rx_size;
          tr.valid =vif.rx_monitor_cb.md_rx_valid;
          tr.err   =vif.rx_monitor_cb.md_rx_err;
          ap.write(tr);
        end
      end
    endtask
  endclass : rx_monitor

  // ===========================================================================
  // TX MONITOR
  // ===========================================================================
  class tx_monitor extends uvm_monitor;
    `uvm_component_utils(tx_monitor)
    uvm_analysis_port #(tx_transaction) ap;
    virtual aligner_if.tx_monitor_mp vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); ap=new("ap",this);
      if(!uvm_config_db#(virtual aligner_if.tx_monitor_mp)::get(this,"","tx_vif",vif))
        `uvm_fatal("TX_MON","No tx_vif")
    endfunction
    task run_phase(uvm_phase phase);
      tx_transaction tr;
      @(posedge vif.clk); while(!vif.reset_n) @(posedge vif.clk);
      forever begin
        @(vif.tx_monitor_cb);
        if(vif.tx_monitor_cb.md_tx_valid && vif.tx_monitor_cb.md_tx_ready) begin
          tr=new("tx_tr");
          tr.data  =vif.tx_monitor_cb.md_tx_data;
          tr.offset=vif.tx_monitor_cb.md_tx_offset;
          tr.size  =vif.tx_monitor_cb.md_tx_size;
          tr.valid =vif.tx_monitor_cb.md_tx_valid;
          tr.err   =vif.tx_monitor_cb.md_tx_err;
          ap.write(tr);
        end
      end
    endtask
  endclass : tx_monitor

  // ===========================================================================
  // IRQ MONITOR
  // ===========================================================================
  class irq_monitor extends uvm_monitor;
    `uvm_component_utils(irq_monitor)
    uvm_analysis_port #(irq_transaction) ap;
    virtual aligner_if.irq_mp vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); ap=new("ap",this);
      if(!uvm_config_db#(virtual aligner_if.irq_mp)::get(this,"","irq_vif",vif))
        `uvm_fatal("IRQ_MON","No irq_vif")
    endfunction
    task run_phase(uvm_phase phase);
      irq_transaction tr;
      @(posedge vif.clk); while(!vif.reset_n) @(posedge vif.clk);
      forever begin
        @(posedge vif.irq_cb.irq);
        tr=new("irq_tr"); tr.irq_detected=1'b1; tr.timestamp=$time;
        `uvm_info("IRQ_MON",tr.convert2string(),UVM_LOW)
        ap.write(tr);
      end
    endtask
  endclass : irq_monitor

  // ===========================================================================
  // TX READY DRIVER
  // ===========================================================================
  class tx_ready_driver extends uvm_component;
    `uvm_component_utils(tx_ready_driver)
    virtual aligner_if.tx_driver_mp vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual aligner_if.tx_driver_mp)::get(this,"","tx_vif",vif))
        `uvm_fatal("TX_RDY","No tx_vif")
    endfunction
    task run_phase(uvm_phase phase);
      vif.tx_driver_cb.md_tx_ready<=1'b1;
      forever @(vif.tx_driver_cb) vif.tx_driver_cb.md_tx_ready<=1'b1;
    endtask
  endclass : tx_ready_driver

  // ===========================================================================
  // AGENTS
  // ===========================================================================
  class rx_agent extends uvm_agent;
    `uvm_component_utils(rx_agent)
    uvm_sequencer #(rx_transaction) sequencer;
    rx_driver  driver;
    rx_monitor monitor;
    uvm_analysis_port #(rx_transaction) ap;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap        = new("ap",this);
      sequencer = uvm_sequencer#(rx_transaction)::type_id::create("sequencer",this);
      driver    = rx_driver::type_id::create("driver",this);
      monitor   = rx_monitor::type_id::create("monitor",this);
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
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ap        = new("ap",this);
      sequencer = uvm_sequencer#(apb_transaction)::type_id::create("sequencer",this);
      driver    = apb_driver::type_id::create("driver",this);
      monitor   = apb_monitor::type_id::create("monitor",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      monitor.ap.connect(ap);
    endfunction
  endclass : apb_agent

  // ===========================================================================
  // ENV
  // ===========================================================================
  class aligner_env extends uvm_env;
    `uvm_component_utils(aligner_env)
    rx_agent    rx_agt;
    apb_agent   apb_agt;
    tx_monitor  tx_mon;
    irq_monitor irq_mon;
    scoreboard  sb;
    cfs_aligner_regs reg_model;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      rx_agt  = rx_agent::type_id::create("rx_agt",   this);
      apb_agt = apb_agent::type_id::create("apb_agt", this);
      tx_mon  = tx_monitor::type_id::create("tx_mon", this);
      irq_mon = irq_monitor::type_id::create("irq_mon",this);
      sb      = scoreboard::type_id::create("sb",      this);
      reg_model = new("reg_model");
      reg_model.build();
      reg_model.lock_model();
      uvm_config_db#(cfs_aligner_regs)::set(this,"*","reg_model",reg_model);
    endfunction
    function void connect_phase(uvm_phase phase);
      apb_adapter adapter;
      rx_agt.ap.connect(sb.rx_export);
      tx_mon.ap.connect(sb.tx_export);
      irq_mon.ap.connect(sb.irq_export);
      adapter = new("adapter");
      reg_model.default_map.set_sequencer(apb_agt.sequencer, adapter);
      reg_model.default_map.set_auto_predict(0);
    endfunction
  endclass : aligner_env

  // ===========================================================================
  // TEST BASE
  // ===========================================================================
  class test_base extends uvm_test;
    `uvm_component_utils(test_base)
    aligner_env      env;
    tx_ready_driver  tx_rdy;
    cfs_aligner_regs reg_model;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env    = aligner_env::type_id::create("env",   this);
      tx_rdy = tx_ready_driver::type_id::create("tx_rdy",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      if(!uvm_config_db#(cfs_aligner_regs)::get(this,"*","reg_model",reg_model))
        `uvm_fatal("TEST","No reg_model")
    endfunction
    task reset_dut();
      uvm_status_e   ral_status;
      uvm_reg_data_t rd_val;
      `uvm_info("TEST","=== reset_dut START ===",UVM_LOW)
      reg_model.irqen.write(ral_status, 32'h0);
      reg_model.irq.write(ral_status, 32'hFFFFFFFF);
      reg_model.irq.read(ral_status, rd_val);
      if(rd_val[4:0] !== 5'b0)
        `uvm_error("TEST",$sformatf("IRQ no limpio: 0x%0X",rd_val))
      `uvm_info("TEST","=== reset_dut DONE ===",UVM_LOW)
    endtask
    task run_phase(uvm_phase phase);
      phase.raise_objection(this); reset_dut(); phase.drop_objection(this);
    endtask
  endclass : test_base

  // ===========================================================================
  // TEST: alineacion basica
  // ===========================================================================
  class test_basic_align extends test_base;
    `uvm_component_utils(test_basic_align)
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
      rx_basic_sequence seq_h;
      uvm_status_e      ral_status;
      uvm_reg_data_t    drop_val;
      phase.raise_objection(this);
      reset_dut();
      `uvm_info("TEST","Configurando CTRL: size=4 offset=0",UVM_LOW)
      reg_model.ctrl.size.write(ral_status, 3'd4);
      reg_model.ctrl.offset.write(ral_status, 2'd0);
      seq_h = new("seq_h");
      seq_h.start(env.rx_agt.sequencer);
      #100;
      reg_model.status.cnt_drop.read(ral_status, drop_val);
      env.sb.set_actual_drops(int'(drop_val));
      `uvm_info("TEST","test_basic_align DONE",UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass : test_basic_align

endpackage : aligner_comp_pkg

// =============================================================================
// TB TOP
// =============================================================================
module tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import cfs_aligner_ral_pkg::*;
  import aligner_tb_pkg::*;
  import aligner_comp_pkg::*;

  logic clk, reset_n;
  initial clk = 0;
  always #5 clk = ~clk;
  initial begin reset_n=1'b0; repeat(10) @(posedge clk); reset_n=1'b1; end

  aligner_if dut_if(.clk(clk), .reset_n(reset_n));
  assign dut_if.md_tx_err = 1'b0;

  cfs_aligner dut(
    .clk(clk), .reset_n(reset_n),
    .paddr(dut_if.paddr),   .pwrite(dut_if.pwrite),
    .psel(dut_if.psel),     .penable(dut_if.penable),
    .pwdata(dut_if.pwdata), .pready(dut_if.pready),
    .prdata(dut_if.prdata), .pslverr(dut_if.pslverr),
    .md_rx_valid(dut_if.md_rx_valid),   .md_rx_data(dut_if.md_rx_data),
    .md_rx_offset(dut_if.md_rx_offset), .md_rx_size(dut_if.md_rx_size),
    .md_rx_ready(dut_if.md_rx_ready),   .md_rx_err(dut_if.md_rx_err),
    .md_tx_valid(dut_if.md_tx_valid),   .md_tx_data(dut_if.md_tx_data),
    .md_tx_offset(dut_if.md_tx_offset), .md_tx_size(dut_if.md_tx_size),
    .md_tx_ready(dut_if.md_tx_ready),   .md_tx_err(dut_if.md_tx_err),
    .irq(dut_if.irq)
  );

  initial begin
    uvm_config_db#(virtual aligner_if.rx_driver_mp)::set(null,"uvm_test_top.*","rx_vif",dut_if);
    uvm_config_db#(virtual aligner_if.rx_monitor_mp)::set(null,"uvm_test_top.*","rx_vif",dut_if);
    uvm_config_db#(virtual aligner_if.tx_monitor_mp)::set(null,"uvm_test_top.*","tv_vif",dut_if);
    uvm_config_db#(virtual aligner_if.tx_driver_mp)::set(null,"uvm_test_top.*","tx_vif",dut_if);
    uvm_config_db#(virtual aligner_if.apb_mp)::set(null,"uvm_test_top.*","apb_vif",dut_if);
    uvm_config_db#(virtual aligner_if.irq_mp)::set(null,"uvm_test_top.*","irq_vif",dut_if);
    run_test();
  end
endmodule : tb_top
