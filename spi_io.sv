interface spi_io
	();
	
	logic clk;
	logic poci;
	logic pico;
	logic cs;

	modport tb (output clk, output cs, output poci, output pico);
	modport peripheral (input clk, input cs, input pico, output poci);
	modport controller (input clk, input cs, input poci, output pico);

endinterface : spi_io