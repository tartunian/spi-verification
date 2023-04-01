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

	always @(posedge clk) c <= a+b;

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

endclass : adder_transaction


virtual class adder_transactor;

	adder_transaction tr;

	pure virtual task run();

endclass : adder_transactor


class adder_driver extends adder_transactor;

	virtual adder_io.tb adder_if;
	event driver_done;

	function new(virtual adder_io.tb adder_if, event driver_done);
		this.adder_if = adder_if;
		this.driver_done = driver_done;
	endfunction : new

	virtual task run();
		forever begin
			for(int i=0; i<10; i+=1) begin
				#10;
				$display("Doing driver stuff...");
			end
			->driver_done;
		end
	endtask: run

endclass : adder_driver


class adder_generator extends adder_transactor;

	mailbox #(adder_transaction) gen2drv, gen2scb;
	int num_trs;

	function new(mailbox #(adder_transaction) gen2drv, gen2scb, int num_trs);
		this.gen2drv = gen2scb;
		this.gen2scb = gen2scb;
		this.num_trs = num_trs;
	endfunction : new

	virtual task run();
		repeat(this.num_trs) begin

		end
	endtask : run

endclass : adder_generator


class environment;

	virtual adder_io adder_if;

	adder_generator gen;
	adder_driver drv;

	event driver_done;
	
	mailbox #(adder_transaction) gen2drv, gen2scb;

	function new(virtual adder_io adder_if);
		this.adder_if = adder_if;
	endfunction : new

	function build();
		this.gen2drv = new();
		this.gen2scb = new();
		this.gen = new(this.gen2drv, this.gen2scb, 5);
		this.drv = new(this.adder_if, this.driver_done);
	endfunction : build

	task run();
		fork
			gen.run();
			drv.run();
		join_any

		$display("waiting on driver...");
		wait(driver_done.triggered);
		$display("driver done!");

	endtask : run

	task wrap_up();
		// 
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

        #1000;
        
		$finish;

	end



endmodule : tb_top
