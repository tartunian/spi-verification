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

`define MAX_BYTES_PER_CS 4

interface spi_io // is this used anywhere?
	();
	
	logic clk; 
	logic poci;
	logic pico;
	logic cs;

	// modport tb (output clk, output cs, output poci, output pico);
	// modport peripheral (input clk, input cs, input pico, output poci);
	// modport controller (input clk, output cs, input poci, output pico);

endinterface : spi_io


interface spi_board_io
	();

	logic       clk;

	logic       controller_rst_l;
	logic [$clog2(`MAX_BYTES_PER_CS+1)-1:0] controller_tx_count;
	logic [7:0] controller_tx_byte;
	logic       controller_tx_dv;
	logic       controller_tx_ready;
	logic [$clog2(`MAX_BYTES_PER_CS+1)-1:0] controller_rx_count;
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
		default input #1 output #2;
		output controller_tx_count;
		output controller_tx_dv;
		output controller_tx_byte;
		output controller_rst_l, 
		output peripheral_rst_l,
		output peripheral_tx_dv;
		output peripheral_tx_byte;
		output peripheral_spi_cs_n;
		input controller_spi_cs_n;  
		input controller_tx_ready;
		input controller_rx_dv;
		input controller_rx_count;
		input controller_rx_byte;
		input peripheral_rx_dv;
		input peripheral_rx_byte;
	endclocking
	
	initial begin

		clk = 1'b0;

		controller_rst_l = 1'b1;
		controller_tx_count = 1;
		controller_tx_byte = 1'b0;
		controller_tx_dv = 1'b0;

		peripheral_rst_l = 1'b1;
		peripheral_tx_byte = 0;
		peripheral_tx_dv = 1'b0;
		peripheral_spi_cs_n = 1'b1;

	end

endinterface : spi_board_io

typedef enum {
	CONTROLLER_WRITE,
	PERIPHERAL_WRITE
} spiOperation_e;

class spi_transaction;
	import utils_pkg::*;

	static  int                 total = 0;

			int                 id = 0;
	rand    spiOperation_e      operation;
	rand    logic [7:0]         data [];
			logic [7:0]         data_expected[ ], data_actual[ ];	
			
	constraint data_size_c { data.size() inside {[1:`MAX_BYTES_PER_CS]}; }

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

virtual class spi_transactor;

	spi_transaction tr;

	pure virtual task run();

endclass : spi_transactor


class spi_generator extends spi_transactor;
	import utils_pkg::*;

	mailbox #(spi_transaction) gen2drv, gen2scb, gen2mon;
	event driver_done, monitor_done, checker_done;
	int num_trs;

	function new(   mailbox #(spi_transaction) gen2drv, gen2scb, gen2mon,
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
class spi_driver extends spi_transactor;
	import utils_pkg::*;

	virtual spi_board_io spi_board_if;
	mailbox #(spi_transaction) gen2drv;
	event driver_start, driver_done, monitor_step_done;
	
	data_array_cg dude;

	int i = 0;

	function new(   virtual spi_board_io spi_board_if, 
					mailbox #(spi_transaction) gen2drv,
					event driver_start, driver_done);
		this.spi_board_if = spi_board_if;
		this.gen2drv = gen2drv;
		this.driver_start = driver_start;
		this.driver_done = driver_done;		
		this.dude = new();
	endfunction : new

	task reset();
		repeat(10) @(posedge spi_board_if.cb);
		
		spi_board_if.cb.controller_rst_l  <= 1'b0;
		spi_board_if.cb.peripheral_rst_l  <= 1'b0;
		repeat(10) @(posedge spi_board_if.clk);

		spi_board_if.cb.controller_rst_l  <= 1'b1;
		spi_board_if.cb.peripheral_rst_l  <= 1'b1;

		// Enable the peripheral
		spi_board_if.cb.peripheral_spi_cs_n <= 1'b0;

	endtask : reset


	task trigger_write();
		this.spi_board_if.controller_tx_dv <= 1'b1;
		this.spi_board_if.cb.peripheral_tx_dv <= 1'b1;
		@(posedge this.spi_board_if.clk);
		this.spi_board_if.controller_tx_dv <= 1'b0;
		this.spi_board_if.cb.peripheral_tx_dv <= 1'b0;
	endtask


	task write(spiOperation_e operation, logic [7:0] data);

		`DEBUG($sformatf("Writing 0x%2h...", data));

		case(operation)
			
			CONTROLLER_WRITE : begin
				this.spi_board_if.controller_tx_byte <= data;
				this.spi_board_if.cb.peripheral_tx_byte <= 8'h00;
			end
			PERIPHERAL_WRITE : begin
				this.spi_board_if.controller_tx_byte <= 8'h00;
				this.spi_board_if.cb.peripheral_tx_byte <= data;
			end

		endcase // operation
		trigger_write();

		`DEBUG("Waiting on controller_tx_ready...");
		@(posedge this.spi_board_if.cb.controller_tx_ready);
		@(posedge this.spi_board_if.cb);

	endtask


	task write_array(spiOperation_e operation, logic [7:0] data []);
		
		@(posedge this.spi_board_if.cb);
		this.spi_board_if.cb.controller_tx_count <= data.size();

		`DEBUG($sformatf("Writing %3d bytes...", data.size()));

		for(i=0; i<data.size(); i+=1) begin
			write(operation, data[i]);			
		end
		
		@(posedge this.spi_board_if.cb);
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

			foreach(tr.data[i]) dude.sample(tr.data[i]);
			$display("coverage: %0f",dude.get_inst_coverage());
			write_array(tr.operation, tr.data);

			->driver_done;
			`DEBUG("(event) driver_done");
		end
	endtask: run

endclass : spi_driver


class spi_scoreboard extends spi_transactor;
	import utils_pkg::*;

	mailbox #(spi_transaction) gen2scb, scb2chk;
	event driver_step_done, driver_done;
	int num_trs;

	function new(   mailbox #(spi_transaction) gen2scb, scb2chk,
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


class spi_monitor extends spi_transactor;
	import utils_pkg::*;

	virtual spi_board_io spi_board_if;
	mailbox #(spi_transaction) gen2mon, mon2chk;
	event driver_start, driver_done, monitor_done;
	coverage cover1;
	int i = 0;

	function new(   virtual spi_board_io spi_board_if, 
					mailbox #(spi_transaction) gen2mon, mon2chk,
					event driver_start, driver_done, monitor_done);
		this.spi_board_if = spi_board_if;
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
			cover1.tr = this.tr

			`DEBUG($sformatf("Waiting for driver_start..."));
			wait(driver_start.triggered);
			`DEBUG("Detected (event) driver_start.");

			case(tr.operation)
				CONTROLLER_WRITE: begin
					
					for(i=0; i<tr.data.size(); i+=1) begin

						`DEBUG($sformatf("Waiting on peripheral_rx_dv (byte %3d)...", i));
						@(negedge spi_board_if.cb.peripheral_rx_dv);
						
						`DEBUG($sformatf("Collecting peripheral_rx_byte (byte %3d)...", i));
						tr.data_actual[i] = spi_board_if.cb.peripheral_rx_byte;
						`DEBUG($sformatf("tr.data_actual: %p", tr.data_actual));
					end
					
				end

				PERIPHERAL_WRITE: begin
					
					for(i=0; i<tr.data.size(); i+=1) begin

						`DEBUG($sformatf("Waiting on controller_rx_dv (byte %3d)...", i));
						@(negedge spi_board_if.cb.controller_rx_dv);
						
						`DEBUG($sformatf("Collecting controller_rx_byte (byte %3d)...", i));
						tr.data_actual[i] = spi_board_if.cb.controller_rx_byte;
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


class spi_checker extends spi_transactor;
	import utils_pkg::*;

	mailbox #(spi_transaction) scb2chk, mon2chk;
	event driver_done, monitor_done, checker_done;
	spi_transaction scb_tr, mon_tr;
	int errors;
	int error = 0;

	function new(mailbox #(spi_transaction) scb2chk, mon2chk, event driver_done, monitor_done, checker_done);
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


class environment;
	import utils_pkg::*;

	virtual spi_board_io spi_board_if;
	
	spi_generator gen;
	spi_scoreboard scb;
	spi_driver drv;
	spi_monitor mon;
	spi_checker chk;
	
	event driver_start, driver_done, monitor_done, checker_done;
	mailbox #(spi_transaction) gen2drv, gen2scb, gen2mon, scb2chk, mon2chk;
	int num_trs = 5;

	function new(virtual spi_board_io spi_board_if);
		this.spi_board_if = spi_board_if;
	endfunction : new

	function build();
		gen2drv = new(num_trs);
		gen2scb = new(num_trs);
		gen2mon = new(num_trs);
		scb2chk = new(num_trs);
		mon2chk = new(num_trs);
		gen = new(gen2drv, gen2scb, gen2mon, driver_done, monitor_done, checker_done, num_trs);
		scb = new(gen2scb, scb2chk, num_trs);
		drv = new(spi_board_if, gen2drv, driver_start, driver_done);
		mon = new(spi_board_if, gen2mon, mon2chk, driver_start, driver_done, monitor_done);
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
		spi_transaction tr;

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

class coverage;
	spi_transaction tr;
	covergroup cg;
		coverpoint tr.operation;
		coverpoint tr.data;
	endgroup : cg
	function new(spi_transaction tr);
		this.tr = tr;
	endfunction
endclass




program automatic testbench (spi_board_io spi_board_if);
	import utils_pkg::*;

	environment env;

	initial begin
		$vcdpluson;
		$dumpfile("tb_dump.vcd");
		$dumpvars;

		// Reset $display colors
		$write("%c[0;37m",27);

		`DEBUG("Starting testbench...");
		env = new(spi_board_if);
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

spi_board_io spi_board_if();

	SPI_Controller_With_Single_CS #(
		.SPI_MODE(SPI_MODE),
		.CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
		.MAX_BYTES_PER_CS(`MAX_BYTES_PER_CS),
		.CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
	) spi_c(
		.i_Rst_L(spi_board_if.cb.controller_rst_l),
		.i_Clk(spi_board_if.cb),

		.i_TX_Count(spi_board_if.cb.controller_tx_count),
		.i_TX_Byte(spi_board_if.cb.controller_tx_byte),
		.i_TX_DV(spi_board_if.cb.controller_tx_dv),
		.o_TX_Ready(spi_board_if.cb.controller_tx_ready),

		.o_RX_Count(spi_board_if.cb.controller_rx_count),
		.o_RX_DV(spi_board_if.cb.controller_rx_dv),
		.o_RX_Byte(spi_board_if.cb.controller_rx_byte),

		.o_SPI_Clk (spi_board_if.cb),
		.i_SPI_POCI(spi_board_if.spi_if.poci),
		.o_SPI_PICO(spi_board_if.spi_if.pico),
		.o_SPI_CS_n(spi_board_if.controller_spi_cs_n)
	);

	SPI_Peripheral #(
		.SPI_MODE(SPI_MODE)
	) spi_p(
		.i_Rst_L(spi_board_if.cb.peripheral_rst_l),
		.i_Clk(spi_board_if.cb),
		
		.i_TX_DV(spi_board_if.cb.peripheral_tx_dv),
		.i_TX_Byte(spi_board_if.cb.peripheral_tx_byte),

		.o_RX_DV(spi_board_if.cb.peripheral_rx_dv),
		.o_RX_Byte(spi_board_if.cb.peripheral_rx_byte),

		.i_SPI_Clk(spi_board_if.cb),
		.i_SPI_PICO(spi_board_if.spi_if.pico),
		.o_SPI_POCI(spi_board_if.spi_if.poci),
		.i_SPI_CS_n(spi_board_if.peripheral_spi_cs_n)
	);

	testbench tb(spi_board_if);

	always #10 spi_board_if.clk <= ~spi_board_if.clk;

endmodule : tb_top
