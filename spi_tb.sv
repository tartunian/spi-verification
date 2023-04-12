


module spi_tb
	import utils_pkg::*;
	import SPI_verification_trANDgen_pkg::*;
	();

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

	logic tmp_poci;


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
	

	spi_driver driver = new ( .spi_board_if(spi_board_if) );


	always #`HALF_CLK_PRD spi_board_if.clk = ~spi_board_if.clk;


	task reset();

		repeat(10) @(posedge spi_board_if.clk);
		
		spi_board_if.controller_rst_l  = 1'b0;
		spi_board_if.peripheral_rst_l  = 1'b0;
		repeat(10) @(posedge spi_board_if.clk);

		spi_board_if.controller_rst_l  = 1'b1;
		spi_board_if.peripheral_rst_l  = 1'b1;

	endtask : reset

	always @(negedge spi_board_if.controller_rx_dv) begin
		`DEBUG($sformatf("controller rx: 0x%h", spi_board_if.controller_rx_byte), 1);
	end

	always @(negedge spi_board_if.peripheral_rx_dv) begin
		`DEBUG($sformatf("peripheral rx: 0x%h", spi_board_if.peripheral_rx_byte), 1);
	end


	initial begin

		$vcdpluson;
        $dumpfile("spi_tb_dump.vcd");
        $dumpvars;

        // Reset the DUTs
        reset();

		// Enable the peripheral
		spi_board_if.peripheral_spi_cs_n = 1'b0;

		`DEBUG("Starting spi_tb...", 0);



		for(int i=0; i<4; i+=1) begin
			driver.controller_write(spi_board_if.controller_rx_byte+1);	
			// `DEBUG( $sformatf("peripheral rx: 0x%h", spi_board_if.peripheral_rx_byte) , 0);
			driver.peripheral_write(spi_board_if.peripheral_rx_byte+1);
			// `DEBUG( $sformatf("controller rx: 0x%h", spi_board_if.controller_rx_byte) , 0);
		end


		// driver.controller_write(8'h01);	
		// `DEBUG( $sformatf("peripheral rx: 0x%h", spi_board_if.peripheral_rx_byte) , 0);
		// driver.peripheral_write(8'h02);
		// `DEBUG( $sformatf("controller rx: 0x%h", spi_board_if.controller_rx_byte) , 0);

		// driver.controller_write(8'h03);	
		// `DEBUG( $sformatf("peripheral rx: 0x%h", spi_board_if.peripheral_rx_byte) , 0);
		// driver.peripheral_write(8'h04);
		// `DEBUG( $sformatf("controller rx: 0x%h", spi_board_if.controller_rx_byte) , 0);

		// driver.peripheral_write(8'h05);
		// `DEBUG( $sformatf("controller rx: 0x%h", spi_board_if.controller_rx_byte) , 0);
		// driver.controller_write(8'h06);	
		// `DEBUG( $sformatf("peripheral rx: 0x%h", spi_board_if.peripheral_rx_byte) , 0);


		// @(posedge spi_board_if.peripheral_rx_dv);
		

		

		// `DEBUG("Waiting for controller rx dv...", 0);
		// @(posedge spi_board_if.controller_rx_dv);
		

		// Wait
		repeat (100) @(posedge spi_board_if.clk);

		$finish;

	end



endmodule : spi_tb