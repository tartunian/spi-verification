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