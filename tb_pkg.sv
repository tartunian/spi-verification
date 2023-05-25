package tb_pkg;
  
typedef enum {
  CONTROLLER_WRITE,
  PERIPHERAL_WRITE
} spiOperation_e;

class spi_transaction
  #(parameter MAX_BYTES_PER_CS);
  import utils_pkg::*;

  static  int         total = 0;

      int                 id = 0;
  rand    spiOperation_e      operation;
  rand    logic [7:0]         data [];
      logic [7:0]         data_expected[ ], data_actual[ ]; 
      
  constraint data_size_c { data.size() inside {[1:MAX_BYTES_PER_CS]}; }

  function new();
    this.id = total;
    this.randomize();

    data_expected = new[data.size()];
    data_actual = new[data.size()];

    total++;
  endfunction : new

  function copy(spi_transaction #(MAX_BYTES_PER_CS) tr);
    this.total = tr.total;
    this.id = tr.id;
    this.operation = tr.operation;
    this.data = tr.data;
    this.data_expected = tr.data_expected;
    this.data_actual = tr.data_actual;
  endfunction : copy  

  function string print();
    $write("%c[0;37m",27);
    `DEBUG_INDENT("=====spi_transaction=====");
    `DEBUG_INDENT($sformatf("id            =%3d", id));
    `DEBUG_INDENT($sformatf("operation     =%p", operation));
    `DEBUG_INDENT($sformatf("data          =%p", data));
    `DEBUG_INDENT($sformatf("data_expected =%p", data_expected));
    `DEBUG_INDENT($sformatf("data_actual   =%p", data_actual));
  endfunction

endclass : spi_transaction

/*class spi_transaction_directed extends spi_transaction;
  import utils_pkg::*;

  function new(spiOperation_e operation, logic [7:0] data []);
    this.id = total;

    this.data = data;
    data_expected = new[data.size()];
    data_actual = new[data.size()];

    total++;
  endfunction : new

endclass : spi_transaction_directed
*/

virtual class spi_transactor
  #(parameter MAX_BYTES_PER_CS);

  spi_transaction #(MAX_BYTES_PER_CS) tr;
  pure virtual task run();

endclass : spi_transactor


// class top_coverage #(parameter MAX_BYTES_PER_CS);

// This class would need a top-top module with a way to supervise all instances of a top module
// each top module would generate new params
// the other way would be to grab the generate variables, but it doesn't look like that is ready
// yet...

//    int spi_mode, max_bytes;

//    function new(parameter SPI_MODE, parameter MAX_BYTES_PER_CS);
//      //this.spi_mode = spi_mode;
//      // cgmat_nz = new(i);
//      // cgmat_z = new(i);
//      this.cg_SPIModule_top = new();
//      this.spi_mode = SPI_MODE;
//      this.max_bytes = MAX_BYTES_PER_CS;
//    endfunction


//    covergroup cg_SPIModule_top() @(checker_done);
//      // Did we try each SPI mode?
//      // How many Max_bytes_per_cs values did we try?
//      cp_SPI_MODE: coverpoint spi_mode;
//      cp_MAX_BYTES: coverpoint max_bytes;
//    endgroup : cg_SPIModule_top

// endclass : top_coverage

// Coverage for the data values
  class module_coverage #(parameter MAX_BYTES_PER_CS  ); // make a class for each program

    event checker_done;
    int i, max_bytes;
    int size;

    spi_transaction #(MAX_BYTES_PER_CS) tr;

    function new(event checker_done,
          spi_transaction #(MAX_BYTES_PER_CS) tr,int i);
      this.checker_done = checker_done;
      this.tr = tr;
      this.i = i;
      cg_controller_meta = new();
      cg_periph_meta = new();
      cg_tr_messages = new(i);
    endfunction

    covergroup cg_controller_meta() @(checker_done);
      option.per_instance = 1;
      // Did the controller perform a write?
      // Did the controller perform a read?
      cp_ctrlRW: coverpoint tr.operation { 
      bins ctrl_write = {0};} 
      // Did we try write then read and read then write?
      cp_ctrlRW_seq: coverpoint tr.operation // not sure how to check this yet...
      {
      bins read_write = (0 => 1);
      bins write_read = (1 => 0);
      }
      // What variety in bytes per transaction?
      cp_msg_size: coverpoint tr.data.size() // gotta define the bins
      {
      bins one_byte = {1};
      bins two_bytes = {2};
      bins three_bytes = {3};
      bins four_bytes = {4};
      } 
      // What sequence of message sizes did we try?
      cp_msg_size_seq: coverpoint tr.data.size() // again, sequential checks are something...
      {
      bins one_to_four = (1 => 4);
      bins four_to_one = (4 => 1);
      }
    endgroup : cg_controller_meta

    covergroup cg_periph_meta() @(checker_done);
      option.per_instance = 1;
      // Did the peripheral perform a write?
      // Did the peripheral perform a read?
      cp_periphRW: coverpoint tr.operation{
      bins periph_write = {1};}
      // Did we try write then read and read then write?
      cp_periphRW_seq: coverpoint tr.operation{
      bins read_write = (0 => 1);
      bins write_read = (1 => 0);
      }
      // What variety of bytes per transaction?
      cp_msg_size: coverpoint tr.data.size(){
      bins range[] = {[1:MAX_BYTES_PER_CS]}; // make a bin for each possible value 
      }
      // What sequence of message sizes did we try?
      cp_msg_size_seq: coverpoint tr.data.size(){
      bins one_to_four = (1 => MAX_BYTES_PER_CS);
      bins four_to_one = (MAX_BYTES_PER_CS => 1);
      }
    endgroup : cg_periph_meta

    covergroup cg_tr_messages(int i) @(checker_done);
      cp_tr_data_edge: coverpoint tr.data[i]{
      bins all_zeros = {0};      // Did we send all 00's?
      bins all_ones = {8'hFF};   // Did we send all FF's?
      bins all_rest = default;
      }
    endgroup : cg_tr_messages


  endclass : module_coverage


class spi_generator #(parameter MAX_BYTES_PER_CS) extends spi_transactor #(MAX_BYTES_PER_CS); 
  import utils_pkg::*;

  mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2drv, gen2scb, gen2mon;
  event driver_done, monitor_done, checker_done;
  int num_trs;

  function new(   mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2drv, gen2scb, gen2mon,
          event driver_done, monitor_done, checker_done, int num_trs);
    this.gen2drv = gen2drv;
    this.gen2scb = gen2scb;
    this.gen2mon = gen2mon;
    this.driver_done = driver_done;
    this.monitor_done = monitor_done;
    this.checker_done = checker_done;
    this.num_trs = num_trs;
  endfunction : new

  task run();
    repeat(num_trs) begin

      `DEBUG("Starting new transaction...");

      tr = new();
      gen2drv.put(tr);
      gen2scb.put(tr);
      gen2mon.put(tr);

      `DEBUG("Put transaction to gen2drv, gen2scb, gen2mon");
      tr.print();
      
      `DEBUG("Waiting for checker_done...");
      // wait(checker_done.triggered);
      @ checker_done;
      `DEBUG("Detected (event) checker_done.");

    end
  endtask : run

endclass : spi_generator
  
class spi_driver #(parameter MAX_BYTES_PER_CS) extends spi_transactor #(MAX_BYTES_PER_CS);
  import utils_pkg::*;

  virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if;
  mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2drv;
  event driver_start, driver_done, monitor_step_done;
  
  int i = 0;

  function new(  virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if, 
          mailbox #(spi_transaction#(MAX_BYTES_PER_CS)) gen2drv,
          event driver_start, driver_done);
    this.vspi_board_if = vspi_board_if;
    this.gen2drv = gen2drv;
    this.driver_start = driver_start;
    this.driver_done = driver_done;   
  endfunction : new

  task reset();
    repeat(10) @(vspi_board_if.cb);
    //$display("Entering reset");
    vspi_board_if.cb.controller_rst_l  <= 1'b0;
    vspi_board_if.cb.controller_tx_byte <= 1'b0;
    vspi_board_if.cb.controller_tx_dv <= 1'b0;
    vspi_board_if.cb.controller_tx_count <= 1;

    vspi_board_if.cb.peripheral_rst_l  <= 1'b0;
    vspi_board_if.cb.peripheral_tx_byte <= 0;
    vspi_board_if.cb.peripheral_tx_dv <= 1'b0;
    vspi_board_if.cb.peripheral_spi_cs_n <= 1'b1;

    repeat(10) @(vspi_board_if.cb);

    vspi_board_if.cb.controller_rst_l  <= 1'b1;
    vspi_board_if.cb.peripheral_rst_l  <= 1'b1;

    // Enable the peripheral
    vspi_board_if.cb.peripheral_spi_cs_n <= 1'b0;

  endtask : reset

  task trigger_write();
    this.vspi_board_if.cb.controller_tx_dv <= 1'b1;
    this.vspi_board_if.cb.peripheral_tx_dv <= 1'b1;
    @(this.vspi_board_if.cb);
    this.vspi_board_if.cb.controller_tx_dv <= 1'b0;
    this.vspi_board_if.cb.peripheral_tx_dv <= 1'b0;
  endtask


  task write(spiOperation_e operation, logic [7:0] data);

    `DEBUG($sformatf("Writing 0x%2h...", data));

    case(operation)
      
      CONTROLLER_WRITE : begin
        this.vspi_board_if.cb.controller_tx_byte <= data;
        this.vspi_board_if.cb.peripheral_tx_byte <= 8'h00;
      end
      PERIPHERAL_WRITE : begin
        this.vspi_board_if.cb.controller_tx_byte <= 8'h00;
        this.vspi_board_if.cb.peripheral_tx_byte <= data;
      end

    endcase // operation
    
    trigger_write();

    `DEBUG("Waiting on controller_tx_ready...");
    @(this.vspi_board_if.cb.controller_tx_ready);
    @(this.vspi_board_if.cb);
    
  endtask


  task write_array(spiOperation_e operation, logic [7:0] data []);
    
    @(this.vspi_board_if.cb);
    this.vspi_board_if.cb.controller_tx_count <= data.size();

    `DEBUG($sformatf("Writing %3d bytes...", data.size()));

    for(i=0; i<data.size(); i+=1) begin
      write(operation, data[i]);      
    end
    
    @(this.vspi_board_if.cb);
    `DEBUG($sformatf("Wrote %3d bytes", data.size()));
  endtask


  task run();
    forever begin
      `DEBUG("Waiting for next transaction...");
      gen2drv.get(tr);
      `DEBUG("Got transaction from gen2drv");
      tr.print();

      ->driver_start;
      `DEBUG("(event) driver_start");

      write_array(tr.operation, tr.data);

      ->driver_done;
      `DEBUG("(event) driver_done");
    end
  endtask: run

endclass : spi_driver


class spi_scoreboard #(parameter MAX_BYTES_PER_CS) extends spi_transactor #(MAX_BYTES_PER_CS);
  import utils_pkg::*;

  mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2scb, scb2chk;
  event driver_step_done, driver_done;
  int num_trs;

  function new(   mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2scb, scb2chk,
          int num_trs);
    this.gen2scb = gen2scb;
    this.scb2chk = scb2chk;
    this.num_trs = num_trs;
  endfunction : new

  task run();
    repeat (num_trs) begin
      gen2scb.get(tr);

      `DEBUG("Got transaction from gen2scb");
      tr.print();

      tr.data_expected = tr.data;
      scb2chk.put(tr);

      `DEBUG("Put transaction to scb2chk");
      tr.print();

    end
  endtask: run

endclass : spi_scoreboard


class spi_monitor #(parameter MAX_BYTES_PER_CS) extends spi_transactor #(MAX_BYTES_PER_CS);
  import utils_pkg::*;

  virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if;
  mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2mon, mon2chk;
  event driver_start, driver_done, monitor_done;
  int i = 0;

  function new(  virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if, 
          mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2mon, mon2chk,
          event driver_start, driver_done, monitor_done);
    this.vspi_board_if = vspi_board_if;
    this.gen2mon = gen2mon;
    this.mon2chk = mon2chk;
    this.driver_start = driver_start;
    this.driver_done = driver_done;
    this.monitor_done = monitor_done;
  endfunction : new

  task run();
    forever begin

      `DEBUG("Waiting for next transaction...");
      gen2mon.get(tr);      
      
      `DEBUG("Got transaction from gen2mon");
      tr.print();

      `DEBUG($sformatf("Waiting for driver_start..."));
      wait(driver_start.triggered);
      `DEBUG("Detected (event) driver_start.");

      case(tr.operation)
        CONTROLLER_WRITE: begin
          
          for(i=0; i<tr.data.size(); i+=1) begin

            `DEBUG($sformatf("Waiting on peripheral_rx_dv (byte %3d)...", i));
            @(vspi_board_if.cb.peripheral_rx_dv); //technically not viable to sample
            @(vspi_board_if.cb)
            `DEBUG($sformatf("Collecting peripheral_rx_byte (byte %3d)...", i));
            tr.data_actual[i] = vspi_board_if.cb.peripheral_rx_byte;
            `DEBUG($sformatf("tr.data_actual: %p", tr.data_actual));
          end
          
        end

        PERIPHERAL_WRITE: begin
          
          for(i=0; i<tr.data.size(); i+=1) begin

            `DEBUG($sformatf("Waiting on controller_rx_dv (byte %3d)...", i));
            @(vspi_board_if.cb.controller_rx_dv); // technically should not be viable to sample...
            @(vspi_board_if.cb);
            `DEBUG($sformatf("Collecting controller_rx_byte (byte %3d)...", i));
            tr.data_actual[i] = vspi_board_if.cb.controller_rx_byte;
            `DEBUG($sformatf("tr.data_actual: %p", tr.data_actual));
          end

        end

      endcase // tr.operation
      
      mon2chk.put(tr);

      `DEBUG("Put transaction to mon2chk");
      tr.print();

      ->monitor_done;
      `DEBUG("(event) monitor_done");
    end
  endtask : run

endclass : spi_monitor


class spi_checker #(parameter MAX_BYTES_PER_CS) extends spi_transactor #(MAX_BYTES_PER_CS);
  import utils_pkg::*;

  mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) scb2chk, mon2chk;
  event driver_done, monitor_done, checker_done;
  spi_transaction #(MAX_BYTES_PER_CS) scb_tr, mon_tr;
  int errors;
  int error = 0;
  module_coverage #(MAX_BYTES_PER_CS) cov_objs [MAX_BYTES_PER_CS];
  spi_transaction #(MAX_BYTES_PER_CS) static_tr;

  real current_cov_periph, current_cov_control, current_cov_top;

  function new( mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) scb2chk, mon2chk, 
          event driver_done, monitor_done, checker_done);
    this.scb2chk = scb2chk;
    this.mon2chk = mon2chk;
    this.driver_done = driver_done;
    this.monitor_done = monitor_done;
    this.checker_done = checker_done;
    static_tr = new();
    foreach(cov_objs[i])
      cov_objs[i] = new(checker_done, static_tr, i);

  endfunction : new

  task run();
    forever begin

      fork
        begin
          `DEBUG("Waiting for driver_done...");
          @ driver_done;
          `DEBUG("Detected (event) driver_done.");

        end
        begin
          `DEBUG("Waiting for monitor_done...");
          @ monitor_done;
          `DEBUG("Detected (event) monitor_done.");
        end
      join

      `DEBUG("Waiting on monitor...");
      mon2chk.get(mon_tr);
      
      `DEBUG("Got transaction from mon2chk");
      mon_tr.print();


      `DEBUG("Waiting on scoreboard...");
      scb2chk.get(scb_tr);

      `DEBUG("Got transaction from scb2chk");
      scb_tr.print();
      static_tr.copy(scb_tr);
      foreach(cov_objs[i]) begin
        //current_cov_top = cov_objs[i].cg_SPIModule_top.get_inst_coverage();
        current_cov_control = cov_objs[i].cg_controller_meta.get_inst_coverage();
        current_cov_periph = cov_objs[i].cg_periph_meta.get_inst_coverage();
      end

      error = scb_tr.data_expected != mon_tr.data_actual;

      `DEBUG($sformatf("Checker result: %s", error==1?"FAIL":"PASS"));

      errors += error;

      ->checker_done;
      `DEBUG("(event) checker_done");

    end
  endtask : run

endclass : spi_checker


class environment #(parameter MAX_BYTES_PER_CS);
  import utils_pkg::*;

  virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if;
  
  spi_generator #(MAX_BYTES_PER_CS) gen;
  spi_scoreboard #(MAX_BYTES_PER_CS) scb;
  spi_driver #(MAX_BYTES_PER_CS) drv;
  spi_monitor #(MAX_BYTES_PER_CS) mon;
  spi_checker #(MAX_BYTES_PER_CS) chk;
  
  event driver_start, driver_done, monitor_done, checker_done;
  mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2drv, gen2scb, gen2mon, scb2chk, mon2chk;
  int num_trs = 100;

  function new(virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if);
    this.vspi_board_if = vspi_board_if;
  endfunction : new

  function build();
    gen2drv = new(num_trs);
    gen2scb = new(num_trs);
    gen2mon = new(num_trs);
    scb2chk = new(num_trs);
    mon2chk = new(num_trs);
    gen = new(gen2drv, gen2scb, gen2mon, driver_done, monitor_done, checker_done, num_trs);
    scb = new(gen2scb, scb2chk, num_trs);
    drv = new(vspi_board_if, gen2drv, driver_start, driver_done);
    mon = new(vspi_board_if, gen2mon, mon2chk, driver_start, driver_done, monitor_done);
    chk = new(scb2chk, mon2chk, driver_done, monitor_done, checker_done);
  endfunction : build

  task run();
    `DEBUG("Starting environment...");
    `DEBUG("Resetting DUT...");
    drv.reset();
    `DEBUG("Reset DUT done.");
    fork
      gen.run();
      scb.run();
      begin : driver_thread
        drv.run();
      end
      mon.run();
      chk.run();
    join_any

    `DEBUG("Waiting for checker_done...");
    @ checker_done;

    disable driver_thread;

    `DEBUG("All processes done");

  endtask : run

  task wrap_up();
    spi_transaction #(MAX_BYTES_PER_CS) tr;

    `DEBUG("Wrapping up...");
    `DEBUG("Cleaning mailboxes...");
    `DEBUG($sformatf("gen2drv: %d transactions", gen2drv.num()));
    `DEBUG($sformatf("gen2scb: %d transactions", gen2scb.num()));
    `DEBUG($sformatf("gen2mon: %d transactions", gen2mon.num()));
    `DEBUG($sformatf("scb2chk: %d transactions", scb2chk.num()));
    `DEBUG($sformatf("mon2chk: %d transactions", mon2chk.num()));

    while(gen2drv.try_get(tr)) begin
      `DEBUG("Cleaned transaction from gen2drv");
    end

    while(gen2scb.try_get(tr)) begin
      `DEBUG("Cleaned transaction from gen2scb");
    end

    while(gen2mon.try_get(tr)) begin
      `DEBUG("Cleaned transaction from gen2mon");
    end

    while(scb2chk.try_get(tr)) begin
      `DEBUG("Cleaned transaction from scb2chk");
    end

    while(mon2chk.try_get(tr)) begin
      `DEBUG("Cleaned transaction from mon2chk");
    end

    `DEBUG($sformatf("TOTAL ERRORS: %3d/%3d (%5f%% )", chk.errors, num_trs, (chk.errors/num_trs)*100));

  endtask : wrap_up

endclass : environment

endpackage