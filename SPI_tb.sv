//`include "dut/Controller/SPI_Controller_With_Single_CS.v"

package DataTypes;



endpackage : DataTypes

module SPI_tb();

	parameter SPI_MODE = 3;
	parameter CLKS_PER_HALF_BIT = 4;
	parameter MAIN_CLK_DELAY = 2;
	parameter MAX_BYTES_PER_CS = 2;
	parameter CS_INACTIVE_CLKS = 10;

	logic 		Clk;

	logic 		Controller_Rst_L;
	logic 		Peripheral_Rst_L;

	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] Controller_TX_Count;
	logic [7:0] Controller_TX_Byte;
	logic		Controller_TX_DV;
	logic		Controller_TX_Ready;

	logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] Controller_RX_Count;
	logic [7:0] Controller_RX_Byte;
	logic		Controller_RX_DV;

	logic [7:0] Peripheral_TX_Byte;
	logic		Peripheral_TX_DV;

	logic [7:0] Peripheral_RX_Byte;
	logic		Peripheral_RX_DV;


	logic		SPI_PICO;
	logic		SPI_POCI;
	logic		SPI_Clk;

	logic 		Controller_SPI_CS_n;
	logic 		Peripheral_SPI_CS_n;


	SPI_Controller_With_Single_CS #(
		.SPI_MODE(SPI_MODE),
		.CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT),
		.MAX_BYTES_PER_CS(MAX_BYTES_PER_CS),
		.CS_INACTIVE_CLKS(CS_INACTIVE_CLKS)
	) spi_c(
		.i_Rst_L(Controller_Rst_L),
		.i_Clk(Clk),

		.i_TX_Count(Controller_TX_Count),
		.i_TX_Byte(Controller_TX_Byte),
		.i_TX_DV(Controller_TX_DV),		
		.o_TX_Ready(Controller_TX_Ready),

		.o_RX_Count(Controller_RX_Count),
		.o_RX_DV(Controller_RX_DV),
		.o_RX_Byte(Controller_RX_Byte),

		.o_SPI_Clk (SPI_Clk),
		.i_SPI_POCI(SPI_POCI),
		.o_SPI_PICO(SPI_PICO),
		.o_SPI_CS_n(Controller_SPI_CS_n)
		
		
	);


	SPI_Peripheral spi_p(
		.i_Rst_L(Peripheral_Rst_L),
		.i_Clk(Clk),
		
		.i_TX_DV(Peripheral_TX_DV),
		.i_TX_Byte(Peripheral_TX_Byte),

		.o_RX_DV(Peripheral_RX_DV),
		.o_RX_Byte(Peripheral_RX_Byte),

		.i_SPI_Clk(SPI_Clk),
		.i_SPI_PICO(SPI_PICO),
		.o_SPI_POCI(SPI_POCI),
		.i_SPI_CS_n(Peripheral_SPI_CS_n)

	);







endmodule : SPI_tb