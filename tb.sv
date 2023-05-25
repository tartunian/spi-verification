program automatic testbench #(parameter MAX_BYTES_PER_CS) (spi_board_io.tb spi_board_if);
	import utils_pkg::*;
	import tb_pkg::*;

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
