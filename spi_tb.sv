
module spi_tb
	import utils_pkg::*;
	();

	parameter SPI_MODE = 3;
	parameter CLKS_PER_HALF_BIT = 4;
	parameter MAIN_CLK_DELAY = 2;
	parameter MAX_BYTES_PER_CS = 2;
	parameter CS_INACTIVE_CLKS = 10;

	logic 		clk;

	logic 		controller_rst_l;
	logic 		peripheral_rst_l;

	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_tx_Count;
	logic [7:0] controller_tx_byte;
	logic		controller_tx_dv;
	logic		controller_tx_ready;

	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_rx_count;
	logic [7:0] controller_rx_byte;
	logic		controller_rx_dv;

	logic [7:0] peripheral_tx_byte;
	logic		peripheral_tx_dv;

	logic [7:0] peripheral_rx_byte;
	logic		peripheral_rx_dv;


	logic		spi_pico;
	logic		spi_poci;
	logic		spi_clk;

	logic 		controller_spi_cs_n;
	logic 		peripheral_spi_cs_n;

	
	spi_io spi_if();


	SPI_Controller_With_Single_CS #(
		.SPI_MODE(SPI_MODE),
		.CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
		.MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
		.CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
	) spi_c(
		.i_Rst_L(controller_rst_l),
		.i_Clk(clk),

		.i_TX_Count(controller_tx_count),
		.i_TX_Byte(controller_tx_byte),
		.i_TX_DV(controller_tx_dv),
		.o_TX_Ready(controller_tx_ready),

		.o_RX_Count(controller_rx_count),
		.o_RX_DV(controller_rx_dv),
		.o_RX_Byte(controller_rx_byte),

		.o_SPI_Clk (spi_if.clk),
		.i_SPI_POCI(spi_if.poci),
		.o_SPI_PICO(spi_if.pico),
		.o_SPI_CS_n(controller_spi_cs_n)
	);


	SPI_Peripheral spi_p(
		.i_Rst_L(peripheral_rst_l),
		.i_Clk(clk),
		
		.i_TX_DV(peripheral_tx_dv),
		.i_TX_Byte(peripheral_tx_byte),

		.o_RX_DV(peripheral_rx_dv),
		.o_RX_Byte(peripheral_rx_byte),

		.i_SPI_Clk(spi_if.clk),
		.i_SPI_PICO(spi_if.pico),
		.o_SPI_POCI(spi_if.poci),
		.i_SPI_CS_n(peripheral_spi_cs_n)

	);
	

	spi_driver driver = new ( .spi_if(spi_if.tb) );

	initial begin
		clk = 0;
	end

	initial begin
		$display("Starting spi_tb...");
		driver.read();
		driver.read();
		driver.read();
	end



endmodule : spi_tb