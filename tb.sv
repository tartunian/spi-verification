package utils_pkg;

	class debug;

		typedef enum {
			BLACK = 30,
			RED = 31,
			GREEN = 32,
			BROWN = 33,
			BLUE = 34,
			MAGENTA = 35,
			CYAN = 36,
			WHITE = 37
		} displayColor_e;

		`define DEBUG(MSG) \
			case ($sformatf("%m")) \
				"$unit::\\environment::run ", \
				"$unit::\\environment::wrap_up ": $write("%c[0;36m",27); \
				"$unit::\\spi_generator::run ": $write("%c[0;35m",27); \
				"$unit::\\spi_driver::run ", \
				"$unit::\\spi_driver::write ", \
				"$unit::\\spi_driver::write_array ", \
				"$unit::\\spi_driver::trigger_write " : $write("%c[0;32m",27); \
				"$unit::\\spi_monitor::run ": $write("%c[0;31m",27); \
				"$unit::\\spi_scoreboard::run ": $write("%c[0;33m",27); \
				"$unit::\\spi_checker::run ": $write("%c[0;34m",27); \
				default: $write("%c[0;37m",27); \
			endcase \
			debug::debug($sformatf("%s:: %-50s time: %0t", $sformatf("%50s", $sformatf("%m")), MSG, $time));
		`define  DEBUG_INDENT(MSG) \
			repeat(50) begin \
				$write(" "); \
			end \
			debug::debug($sformatf("%s", MSG ));

		static bit enable_output_file = 0;
		static integer output_file;

		static function debug_to_file(string msg);
			if(output_file === 32'bx)
				output_file = $fopen("debug_output.txt", "w");
			$fwrite(output_file, msg);
			$fwrite(output_file,"\n");
		endfunction

		static function debug(string msg);
			$display(msg);
			if(enable_output_file)
				debug_to_file(msg);
		endfunction

		static function close();
			$fclose(output_file);
		endfunction

	endclass

endpackage : utils_pkg

//`define MAX_BYTES_PER_CS 4

interface spi_io
	();
	
	logic clk; 
	logic poci;
	logic pico;
	logic cs;

	// modport tb (output clk, output cs, output poci, output pico);
	// modport peripheral (input clk, input cs, input pico, output poci);
	// modport controller (input clk, output cs, input poci, output pico);

endinterface : spi_io


interface spi_board_io #(parameter MAX_BYTES_PER_CS);

	logic       clk;

	logic       controller_rst_l;
	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_tx_count;
	logic [7:0] controller_tx_byte;
	logic       controller_tx_dv;
	logic       controller_tx_ready;
	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_rx_count;
	logic       controller_rx_dv;
	logic [7:0] controller_rx_byte;
	logic       controller_spi_cs_n;

	logic       peripheral_rst_l;
	logic       peripheral_tx_dv;
	logic [7:0] peripheral_tx_byte; 
	logic       peripheral_rx_dv;
	logic [7:0] peripheral_rx_byte;
	logic       peripheral_spi_cs_n;

	spi_io spi_if();

	clocking cb @(posedge clk);
		//default input #10 output #1;
		input controller_rx_dv;
		input controller_rx_byte;
		input controller_rx_count;
		input peripheral_rx_dv;
		input controller_tx_ready;
		input peripheral_rx_byte;
		input controller_spi_cs_n;
		output controller_tx_dv;
		output controller_tx_byte;
		output controller_tx_count;
		output controller_rst_l;
		output peripheral_tx_dv;
		output peripheral_tx_byte;
		output peripheral_rst_l;
		output peripheral_spi_cs_n;
	endclocking

  modport tb(clocking cb);

endinterface : spi_board_io

// typedef virtual spi_board_io#(MAX_BYTES_PER_CS).tb vIfcTB;

typedef enum {
	CONTROLLER_WRITE,
	PERIPHERAL_WRITE
} spiOperation_e;

class spi_transaction
	#(parameter MAX_BYTES_PER_CS);
	import utils_pkg::*;

	static  int					total = 0;

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

// Coverage for the data values
	class Coverage #(parameter MAX_BYTES_PER_CS	); // make a class for each program

		event checker_done;
		int i, spi_mode, max_bytes;

		spi_transaction #(MAX_BYTES_PER_CS) tr;

		function new(event checked,
					spi_transaction #(MAX_BYTES_PER_CS) tr,
					int i,
					int spi_mode,
					int max_bytes);
			this.i = i;
			this.checker_done = checked;
			this.tr = tr;
			this.spi_mode = spi_mode;
			// cgmat_nz = new(i);
			// cgmat_z = new(i);
			cg_SPIModule_top = new();
			cg_controller_meta = new();
			cg_periph_meta = new();
			cg_tr_messages = new();
		endfunction


		covergroup cg_SPIModule_top();
			// Did we try each SPI mode?
			// How many Max_bytes_per_cs values did we try?
			cp_SPI_MODE: coverpoint spi_mode;
			cp_MAX_BYTES: coverpoint max_bytes;
		endgroup : cg_SPIModule_top

		covergroup cg_controller_meta();
			// Did the controller perform a write?
			// Did the controller perform a read?
			cp_ctrlRW: coverpoint tr.operation { 
			bins ctrl_write = {0};} 
			// Did we try write then read and read then write?
			cp_ctrlRW_seq: coverpoint tr.operation; // not sure how to check this yet...
			// What variety in bytes per transaction?
			cp_msg_size: coverpoint tr.data.size(); // gotta define the bins 
			// What sequence of message sizes did we try?
			cp_msg_size_seq: coverpoint tr.data.size(); // again, sequential checks are something...
		endgroup : cg_controller_meta

		covergroup cg_periph_meta();
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
			cp_msg_size: coverpoint tr.data.size();
			// What sequence of message sizes did we try?
			cp_msg_size_seq: coverpoint tr.data.size();
		endgroup : cg_periph_meta

		covergroup cg_tr_messages();
			// Did we send all FF's?
			// Did we send all 00's?
			cp_tr_data_edge: coverpoint tr.data_in;
		endgroup : cg_tr_messages

		// Good covergroup - checks the following
		//	for all i:
		//	-A[i] happened, -B[i] happened?
		//	-A[i]x-B[i], -A[i]xB[i], 
		//		A[i]x-B[i], A[i]xB[i] happened?

		// covergroup cgmat_nz(int i) @(checked);
		// 	option.per_instance = 1;
		// 	cp_mat_A: coverpoint tr.matrixA[i][7];
		// 	cp_mat_B: coverpoint tr.matrixB[i][7];
		// 	cp_mat_C: coverpoint tr.matrixC[i][7];
		// 	// Bad approach example
		// 	// bins signs[] = {[-128:0], [1:$]};
		// 	cp_AxB: cross cp_mat_A, cp_mat_B;
		// endgroup;

		// Good covergroup - checks the following
		//	for all i:
		//	- A[i] == 0, B[i] == 0 happened?
		//	- A[i]xB[i] happened?
		
		// covergroup cgmat_z(int i) @(checked);
		// 	option.per_instance = 1;
		// 	cp_mat_A_zero: coverpoint tr.matrixA[i]{
		// 		bins zero = {0};
		// 	}
		// 	cp_mat_B_zero: coverpoint tr.matrixB[i]{
		// 		bins zero = {0};
		// 	}
		// 	cp_mat_C_zero: coverpoint tr.matrixC[i]{
		// 		bins zero = {0};
		// 	}
		// 	cp_AxB: cross cp_mat_A_zero, cp_mat_B_zero;
		// endgroup;

	endclass : Coverage


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
	
	covergroup data_array_cg with function sample(byte b);
		coverpoint b;
	endgroup : data_array_cg
	
/*	covergroup other_tr_cg();
		coverpoint tr.operation;
		coverpoint tr.data.size();
	endgroup : other_tr_cg
*/
class spi_driver #(parameter MAX_BYTES_PER_CS) extends spi_transactor #(MAX_BYTES_PER_CS);
	import utils_pkg::*;

	virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if;
	mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) gen2drv;
	event driver_start, driver_done, monitor_step_done;
	
//	data_array_cg dude;

	int i = 0;

	function new(  virtual spi_board_io#(MAX_BYTES_PER_CS).tb vspi_board_if, 
					mailbox #(spi_transaction#(MAX_BYTES_PER_CS)) gen2drv,
					event driver_start, driver_done);
		this.vspi_board_if = vspi_board_if;
		this.gen2drv = gen2drv;
		this.driver_start = driver_start;
		this.driver_done = driver_done;		
		//this.dude = new();
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
		@(this.vspi_board_if.cb.controller_tx_ready); //need a different way to do this, can't sample it...
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

//			foreach(tr.data[i]) dude.sample(tr.data[i]);
//			$display("coverage: %0f",dude.get_inst_coverage());
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
	//coverage cover1;
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
		//	cover1.tr = this.tr

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

	function new(	mailbox #(spi_transaction #(MAX_BYTES_PER_CS)) scb2chk, mon2chk, 
					event driver_done, monitor_done, checker_done);
		this.scb2chk = scb2chk;
		this.mon2chk = mon2chk;
		this.driver_done = driver_done;
		this.monitor_done = monitor_done;
		this.checker_done = checker_done;
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
	int num_trs = 5;

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

	//	this.drv.data_array_cg

	endtask : wrap_up

endclass : environment

/*class coverage;
	spi_transaction tr;
	covergroup cg;
		coverpoint tr.operation;
		coverpoint tr.data;
	endgroup : cg
	function new(spi_transaction tr);
		this.tr = tr;
	endfunction
endclass
*/

program automatic testbench #(parameter MAX_BYTES_PER_CS) (spi_board_io.tb spi_board_if);
	import utils_pkg::*;

	environment #(MAX_BYTES_PER_CS) env;
	virtual spi_board_io#(MAX_BYTES_PER_CS).tb vifc = spi_board_if;

	initial begin
		$vcdpluson;
		$dumpfile("tb_dump.vcd");
		$dumpvars;

		// Reset $display colors
		$write("%c[0;37m",27);

		`DEBUG("Starting testbench...");

    env = new(vifc);
		env.build();
		env.run();
		env.wrap_up();
		//
		// Reset $display colors
		$write("%c[0;37m",27);
		
		$finish;		

	end

endprogram : testbench


module tb_top();
	import utils_pkg::*;
	parameter MAX_BYTES_PER_CS = 4;
	parameter SPI_MODE = 3;
	parameter CLKS_PER_HALF_BIT = 4;
	parameter CS_INACTIVE_CLKS = 10;
	int hi;

//	parameter RANDO_PARAM = $urandom_range(0,8);
//genvar = j;
//generate
// 	for(i=0;i<4;i=i+1)begin : spi_inyourface
// 		spi_board_io #(
// 		  .`MAX_BYTES_PER_CS($urandom_range(0,8))
// 	) spi_board_if ();
// 	end
// endgenerate 

spi_board_io #(MAX_BYTES_PER_CS) spi_board_if();

	SPI_Controller_With_Single_CS #(
		.SPI_MODE(SPI_MODE),
		.CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
		.MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
		.CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
	) spi_c(
		.i_Rst_L(spi_board_if.controller_rst_l),
		.i_Clk(spi_board_if.clk),

		.i_TX_Count(spi_board_if.controller_tx_count),
		.i_TX_Byte(spi_board_if.controller_tx_byte),
		.i_TX_DV(spi_board_if.controller_tx_dv),
		.o_TX_Ready(spi_board_if.controller_tx_ready),

		.o_RX_Count(spi_board_if.controller_rx_count),
		.o_RX_DV(spi_board_if.controller_rx_dv),
		.o_RX_Byte(spi_board_if.controller_rx_byte),

		.o_SPI_Clk (spi_board_if.spi_if.clk),
		.i_SPI_POCI(spi_board_if.spi_if.poci),
		.o_SPI_PICO(spi_board_if.spi_if.pico),
		.o_SPI_CS_n(spi_board_if.controller_spi_cs_n)
	);

	SPI_Peripheral #(
		.SPI_MODE(SPI_MODE)
	) spi_p(
		.i_Rst_L(spi_board_if.peripheral_rst_l),
		.i_Clk(spi_board_if.clk),
		
		.i_TX_DV(spi_board_if.peripheral_tx_dv),
		.i_TX_Byte(spi_board_if.peripheral_tx_byte),

		.o_RX_DV(spi_board_if.peripheral_rx_dv),
		.o_RX_Byte(spi_board_if.peripheral_rx_byte),

		.i_SPI_Clk(spi_board_if.spi_if.clk),
		.i_SPI_PICO(spi_board_if.spi_if.pico),
		.o_SPI_POCI(spi_board_if.spi_if.poci),
		.i_SPI_CS_n(spi_board_if.peripheral_spi_cs_n)
	);

	initial spi_board_if.clk <= 0;

	testbench #(MAX_BYTES_PER_CS) tb(spi_board_if.tb);

	always #10 spi_board_if.clk <= ~spi_board_if.clk;

endmodule : tb_top
