
module tb_top();
  import utils_pkg::*;
  parameter MAX_BYTES_PER_CS = 4;
  parameter SPI_MODE = 3;
  parameter CLKS_PER_HALF_BIT = 4;
  parameter CS_INACTIVE_CLKS = 10;
  //top_coverage top_cvg = new(SPI_MODE,MAX_BYTES_PER_CS);

  //int hi;

//  parameter RANDO_PARAM = $urandom_range(0,8);
//genvar = j;
//generate
//  for(i=0;i<4;i=i+1)begin : spi_inyourface
//    spi_board_io #(
//      .`MAX_BYTES_PER_CS($urandom_range(0,8))
//  ) spi_board_if ();
//  end
// endgenerate 

  spi_board_io #(MAX_BYTES_PER_CS) spi_board_if();

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

  initial spi_board_if.clk <= 0;

  testbench #(MAX_BYTES_PER_CS) tb(spi_board_if.tb);

  always #10 spi_board_if.clk <= ~spi_board_if.clk;

endmodule : tb_top
