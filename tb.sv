package utils;

	class debug;

		`define 		DEBUG(MSG) debug::debug($sformatf("%s:: %s", $sformatf("%30s", $sformatf("%m")), MSG ));
		`define  DEBUG_INDENT(MSG) debug::debug($sformatf("                                 %s", MSG ));

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

endpackage : utils


package adder_types;

	typedef logic [7:0] adder_in_t;
	typedef logic [8:0] adder_out_t;

endpackage : adder_types


module adder
	import adder_types::*;
	(input logic clk,
	input adder_in_t a,
	input adder_out_t b,
	output adder_out_t c);

	always @(posedge clk) c <= a-b;

endmodule : adder


interface adder_io;
	import adder_types::*;

	adder_in_t a, b;
	adder_out_t c;

	modport tb (output a, output b, input c);

endinterface : adder_io


class adder_transaction;

	rand adder_types::adder_in_t a, b;
	adder_types::adder_out_t c_expected, c_actual;

	function new();
	endfunction : new

	function string to_string();
		return $sformatf("a=%4d b=%4d c_expected=%4d c_actual=%4d", a, b, c_expected, c_actual);
	endfunction : to_string

endclass : adder_transaction


virtual class adder_transactor;

	adder_transaction tr;

	pure virtual task run();

endclass : adder_transactor


class adder_generator extends adder_transactor;
	import utils::*;

	mailbox #(adder_transaction) gen2drv, gen2scb, gen2mon;
	event driver_done;
	int num_trs;

	function new(	mailbox #(adder_transaction) gen2drv, gen2scb, gen2mon,
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

endclass : adder_generator


class adder_driver extends adder_transactor;
	import utils::*;

	virtual adder_io.tb adder_if;
	mailbox #(adder_transaction) gen2drv;
	event driver_done;

	function new(	virtual adder_io.tb adder_if, 
					mailbox #(adder_transaction) gen2drv, event driver_done);
		this.adder_if = adder_if;
		this.gen2drv = gen2drv;
		this.driver_done = driver_done;
	endfunction : new

	task add(integer a, b);
		`DEBUG($sformatf("Running with parameters a=%4d b=%4d", a, b));
		adder_if.a <= a;
		adder_if.b <= b;
		#100;
	endtask

	virtual task run();
		forever begin
			gen2drv.get(tr);
			`DEBUG("Got transaction from gen2drv");
			`DEBUG_INDENT(tr.to_string());

			add(tr.a, tr.b);

			->driver_done;
			`DEBUG("driver done");
		end
	endtask: run

endclass : adder_driver


class adder_scoreboard extends adder_transactor;
	import utils::*;

	virtual adder_io.tb adder_if;
	mailbox #(adder_transaction) gen2scb, scb2chk;
	event driver_done;
	int num_trs;

	function new(	mailbox #(adder_transaction) gen2scb, scb2chk,
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

			tr.c_expected = tr.a + tr.b;
			scb2chk.put(tr);

			`DEBUG("Put transaction to scb2chk");
			`DEBUG_INDENT(tr.to_string());

		end
	endtask: run

endclass : adder_scoreboard


class adder_monitor extends adder_transactor;
	import utils::*;

	virtual adder_io.tb adder_if;
	mailbox #(adder_transaction) gen2mon, mon2chk;
	event driver_done;

	function new(	virtual adder_io.tb adder_if, 
					mailbox #(adder_transaction) gen2mon, mon2chk, event driver_done);
		this.adder_if = adder_if;
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
			
			tr.c_actual = adder_if.c;
			mon2chk.put(tr);

			`DEBUG("Put transaction to mon2chk");
			`DEBUG_INDENT(tr.to_string());
		end
	endtask : run

endclass : adder_monitor

class adder_checker extends adder_transactor;
	import utils::*;

	mailbox #(adder_transaction) scb2chk, mon2chk;
	event checker_done;
	adder_transaction scb_tr, mon_tr;
	int errors;
	int error = 0;

	function new(mailbox #(adder_transaction) scb2chk, mon2chk, event checker_done);
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

			error = scb_tr.c_expected!=mon_tr.c_actual;
			`DEBUG($sformatf("Error Result: c_expected=%4d c_actual=%4d error=%d", scb_tr.c_expected, mon_tr.c_actual, error));

			errors += error;

			->checker_done;

		end
	endtask : run


endclass : adder_checker


class environment;
	import utils::*;

	virtual adder_io adder_if;
	
	adder_generator gen;
	adder_scoreboard scb;
	adder_driver drv;
	adder_monitor mon;
	adder_checker chk;
	
	event driver_done, checker_done;
	mailbox #(adder_transaction) gen2drv, gen2scb, gen2mon, scb2chk, mon2chk;
	int num_trs = 5;

	function new(virtual adder_io adder_if);
		this.adder_if = adder_if;
	endfunction : new

	function build();
		gen2drv = new(num_trs);
		gen2scb = new(num_trs);
		gen2mon = new(num_trs);
		scb2chk = new(num_trs);
		mon2chk = new(num_trs);
		gen = new(gen2drv, gen2scb, gen2mon, driver_done, num_trs);
		scb = new(gen2scb, scb2chk, num_trs);
		drv = new(adder_if, gen2drv, driver_done);
		mon = new(adder_if, gen2mon, mon2chk, driver_done);
		chk = new(scb2chk, mon2chk, checker_done);
	endfunction : build

	task run();
		fork
			gen.run();
			scb.run();
			begin : driver_thread
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
		adder_transaction tr;
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


program automatic testbench(adder_io adder_if);

	environment env;

	initial begin

		$display("program testbench starting...");

		env = new(adder_if);
		env.build();
		env.run();
		env.wrap_up();

	end

endprogram : testbench


module tb_top();

	logic			clk = 1'b0;
	adder_io 		adder_if();
	adder 			dut ( .clk(clk), .a(adder_if.a), .b(adder_if.b), .c(adder_if.c) );

	testbench tb(adder_if);

	always #10 clk <= ~clk;

	initial begin

		$vcdpluson;
        $dumpfile("tb_dump.vcd");
        $dumpvars;

        $display("Starting testbench...");

        #1000;
        
		$finish;

	end



endmodule : tb_top
