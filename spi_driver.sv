import utils_pkg::*;

class spi_driver;

	virtual spi_io.tb spi_if;

	function new(virtual spi_io.tb spi_if);
		this.spi_if = spi_if;
	endfunction : new

	task read();
		#`HALF_CLK_PRD;
		#`HALF_CLK_PRD;
		`DEBUG("read complete", 1);
	endtask : read

	task write();
		#`HALF_CLK_PRD;
		#`HALF_CLK_PRD;
	endtask : write

endclass : spi_driver