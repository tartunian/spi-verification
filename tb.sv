package utils_pkg;

	class debug;

		`define 		DEBUG(MSG) debug::debug($sformatf("%s:: %s", $sformatf("%40s", $sformatf("%m")), MSG ));
		`define  DEBUG_INDENT(MSG) debug::debug($sformatf("                                           %s", MSG ));

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


interface spi_io
	();
	
	logic clk;
	logic poci;
	logic pico;
	logic cs;

	modport tb (output clk, output cs, output poci, output pico);
	modport peripheral (input clk, input cs, input pico, output poci);
	modport controller (input clk, output cs, input poci, output pico);

endinterface : spi_io


interface spi_board_io
	#(parameter MAX_BYTES_PER_CS=1)
	();

	logic 		clk;

	logic 		controller_rst_l;
	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_tx_count;
	logic [7:0] controller_tx_byte;
	logic 		controller_tx_dv;
	logic 		controller_tx_ready;
	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_rx_count;
	logic 		controller_rx_dv;
	logic [7:0] controller_rx_byte;
	logic		controller_spi_cs_n;

	logic 		peripheral_rst_l;
	logic 		peripheral_tx_dv;
	logic [7:0] peripheral_tx_byte;	
	logic 		peripheral_rx_dv;
	logic [7:0] peripheral_rx_byte;
	logic		peripheral_spi_cs_n;

	spi_io spi_if();

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


class spi_transaction;

	typedef enum {
		CONTROLLER_WRITE,
		PERIPHERAL_WRITE
	} transactionType_e;

	rand 	logic [7:0] 		data;
			logic [7:0] 		data_expected, data_actual;
	rand 	transactionType_e 	tr_type;

	function new();
	endfunction : new

	function string to_string();
		return $sformatf("spi_transaction::tr_type=%p data=%4d data_expected=%4d data_actual=%4d", tr_type, data, data_expected, data_actual);
	endfunction : to_string

endclass : spi_transaction


virtual class spi_transactor;

	spi_transaction tr;

	pure virtual task run();

endclass : spi_transactor


class spi_generator extends spi_transactor;
	import utils_pkg::*;

	mailbox #(spi_transaction) gen2drv, gen2scb, gen2mon;
	event driver_done;
	int num_trs;

	function new(	mailbox #(spi_transaction) gen2drv, gen2scb, gen2mon,
					event driver_done, int num_trs);
		this.gen2drv = gen2drv;
		this.gen2scb = gen2scb;
		this.gen2mon = gen2mon;
		this.driver_done = driver_done;
		this.num_trs = num_trs;
	endfunction : new

	virtual task run();
		repeat(num_trs) begin
			tr = new();
			tr.randomize();
			gen2drv.put(tr);
			gen2scb.put(tr);
			gen2mon.put(tr);

			`DEBUG("Put transaction to gen2drv, gen2scb, gen2mon");
			`DEBUG_INDENT(tr.to_string());
			
			@ driver_done;
		end
	endtask : run

endclass : spi_generator


class spi_driver extends spi_transactor;
	import utils_pkg::*;

	virtual spi_board_io spi_board_if;
	mailbox #(spi_transaction) gen2drv;
	event driver_done;

	function new(	virtual spi_board_io spi_board_if, 
					mailbox #(spi_transaction) gen2drv, event driver_done);
		this.spi_board_if = spi_board_if;
		this.gen2drv = gen2drv;
		this.driver_done = driver_done;
	endfunction : new

	task reset();
		repeat(10) @(posedge spi_board_if.clk);
		
		spi_board_if.controller_rst_l  = 1'b0;
		spi_board_if.peripheral_rst_l  = 1'b0;
		repeat(10) @(posedge spi_board_if.clk);

		spi_board_if.controller_rst_l  = 1'b1;
		spi_board_if.peripheral_rst_l  = 1'b1;
	endtask : reset

	task setup_controller_write(logic [7:0] write_value);
		this.spi_board_if.controller_tx_byte <= write_value;
		this.spi_board_if.controller_tx_dv <= 1'b1;
	endtask


	task setup_peripheral_write(logic [7:0] write_value);
		this.spi_board_if.peripheral_tx_byte <= write_value;
		this.spi_board_if.peripheral_tx_dv <= 1'b1;
	endtask


	task trigger_write();
		this.spi_board_if.controller_tx_dv <= 1'b0;
		this.spi_board_if.peripheral_tx_dv <= 1'b0;
	endtask


	task controller_write(logic [7:0] write_value);
		@(posedge this.spi_board_if.clk);
		setup_controller_write(write_value);
		setup_peripheral_write(8'h00);
		
		`DEBUG($sformatf("put %4d", write_value));

		@(posedge this.spi_board_if.clk);
		trigger_write();
		
		@(posedge this.spi_board_if.clk);
		@(posedge this.spi_board_if.controller_tx_ready);		
		
	endtask : controller_write	


	task peripheral_write(logic [7:0] write_value);
		@(posedge this.spi_board_if.clk);
		setup_controller_write(8'h00);
		setup_peripheral_write(write_value);

		`DEBUG($sformatf("put %4d", write_value));
		
		@(posedge this.spi_board_if.clk);
		trigger_write();
		
		@(posedge this.spi_board_if.clk);
		@(posedge this.spi_board_if.controller_tx_ready);
		
	endtask : peripheral_write

	virtual task run();
		forever begin
			gen2drv.get(tr);
			`DEBUG("Got transaction from gen2drv");
			`DEBUG_INDENT(tr.to_string());

			case(tr.tr_type)
				tr.CONTROLLER_WRITE: begin
					controller_write(tr.data);
				end
				tr.PERIPHERAL_WRITE: begin
					peripheral_write(tr.data);
				end
			endcase // tr.tr_type

			->driver_done;
			`DEBUG("driver done");
		end
	endtask: run

endclass : spi_driver


class spi_scoreboard extends spi_transactor;
	import utils_pkg::*;

	mailbox #(spi_transaction) gen2scb, scb2chk;
	event driver_done;
	int num_trs;

	function new(	mailbox #(spi_transaction) gen2scb, scb2chk,
					int num_trs);
		this.gen2scb = gen2scb;
		this.scb2chk = scb2chk;
		this.num_trs = num_trs;
	endfunction : new

	virtual task run();
		repeat (num_trs) begin
			gen2scb.get(tr);

			`DEBUG("Got transaction from gen2scb");
			`DEBUG_INDENT(tr.to_string());

			// tr.c_expected = tr.a + tr.b;
			`DEBUG("TBD - DO SCOREBOARD STUFF...");
			scb2chk.put(tr);

			`DEBUG("Put transaction to scb2chk");
			`DEBUG_INDENT(tr.to_string());

		end
	endtask: run

endclass : spi_scoreboard


class spi_monitor extends spi_transactor;
	import utils_pkg::*;

	virtual spi_board_io spi_board_if;
	mailbox #(spi_transaction) gen2mon, mon2chk;
	event driver_done;

	function new(	virtual spi_board_io spi_board_if, 
					mailbox #(spi_transaction) gen2mon, mon2chk, event driver_done);
		this.spi_board_if = spi_board_if;
		this.gen2mon = gen2mon;
		this.mon2chk = mon2chk;
		this.driver_done = driver_done;
	endfunction : new

	task run();
		forever begin
			gen2mon.get(tr);
			@ driver_done;
			
			`DEBUG("Got transaction from gen2mon");
			`DEBUG_INDENT(tr.to_string());
			
			case(tr.tr_type)
				tr.CONTROLLER_WRITE: begin
					tr.data_actual = spi_board_if.controller_rx_byte;
				end
				tr.PERIPHERAL_WRITE: begin
					tr.data_actual = spi_board_if.peripheral_rx_byte;
				end
			endcase // tr.tr_type
			
			mon2chk.put(tr);

			`DEBUG("Put transaction to mon2chk");
			`DEBUG_INDENT(tr.to_string());
		end
	endtask : run

endclass : spi_monitor

class spi_checker extends spi_transactor;
	import utils_pkg::*;

	mailbox #(spi_transaction) scb2chk, mon2chk;
	event checker_done;
	spi_transaction scb_tr, mon_tr;
	int errors;
	int error = 0;

	function new(mailbox #(spi_transaction) scb2chk, mon2chk, event checker_done);
		this.scb2chk = scb2chk;
		this.mon2chk = mon2chk;
		this.checker_done = checker_done;
	endfunction : new

	task run();
		forever begin
			scb2chk.get(scb_tr);

			`DEBUG("Got transaction from scb2chk");
			`DEBUG_INDENT(scb_tr.to_string());

			mon2chk.get(mon_tr);
			
			`DEBUG("Got transaction from mon2chk");
			`DEBUG_INDENT(mon_tr.to_string());

			// error = scb_tr.c_expected!=mon_tr.c_actual;
			`DEBUG("TBD - DO CHECKER STUFF...");
			// `DEBUG($sformatf("Error Result: c_expected=%4d c_actual=%4d error=%d", scb_tr.c_expected, mon_tr.c_actual, error));

			errors += error;

			->checker_done;

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
	
	event driver_done, checker_done;
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
		gen = new(gen2drv, gen2scb, gen2mon, driver_done, num_trs);
		scb = new(gen2scb, scb2chk, num_trs);
		drv = new(spi_board_if, gen2drv, driver_done);
		mon = new(spi_board_if, gen2mon, mon2chk, driver_done);
		chk = new(scb2chk, mon2chk, checker_done);
	endfunction : build

	task run();
		`DEBUG("Starting environment...");
		fork
			gen.run();
			scb.run();
			begin : driver_thread
				drv.reset();
				drv.run();
			end
			mon.run();
			chk.run();
		join_any
		@ driver_done;
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

		while(gen2drv.try_get(tr))
			`DEBUG("Cleaned transaction from gen2drv");

		while(gen2scb.try_get(tr))
			`DEBUG("Cleaned transaction from gen2scb");

		while(gen2mon.try_get(tr))
			`DEBUG("Cleaned transaction from gen2mon");

		while(scb2chk.try_get(tr))
			`DEBUG("Cleaned transaction from scb2chk");

		while(mon2chk.try_get(tr))
			`DEBUG("Cleaned transaction from mon2chk");

		`DEBUG($sformatf("TOTAL ERRORS: %3d/%3d (%5f%% )", chk.errors, num_trs, chk.errors/num_trs*100));

	endtask : wrap_up

endclass : environment


program automatic testbench(spi_board_io spi_board_if);
	import utils_pkg::*;

	environment env;

	initial begin

		`DEBUG("Starting testbench program...");

		env = new(spi_board_if);
		env.build();
		env.run();
		env.wrap_up();

	end

endprogram : testbench


module tb_top();
	import utils_pkg::*;

	parameter SPI_MODE = 3;
	parameter CLKS_PER_HALF_BIT = 4;
	parameter MAX_BYTES_PER_CS = 1;
	parameter CS_INACTIVE_CLKS = 10;

	spi_board_io #( 
		.MAX_BYTES_PER_CS(MAX_BYTES_PER_CS)
	) spi_board_if ();


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

	testbench tb(spi_board_if);

	always #10 spi_board_if.clk <= ~spi_board_if.clk;

	initial begin

		$vcdpluson;
        $dumpfile("tb_dump.vcd");
        $dumpvars;

        `DEBUG("Starting testbench...");

       	#10000;
        
		$finish;

	end



endmodule : tb_top
