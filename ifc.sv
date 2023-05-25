interface spi_io
  ();
  
  logic clk; 
  logic poci;
  logic pico;
  logic cs;

  // modport tb (output clk, output cs, output poci, output pico);
  // modport peripheral (input clk, input cs, input pico, output poci);
  // modport controller (input clk, output cs, input poci, output pico);

endinterface : spi_io


interface spi_board_io #(parameter MAX_BYTES_PER_CS);

  logic       clk;

  logic       controller_rst_l;
  logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_tx_count;
  logic [7:0] controller_tx_byte;
  logic       controller_tx_dv;
  logic       controller_tx_ready;
  logic [$clog2(MAX_BYTES_PER_CS+1)-1:0] controller_rx_count;
  logic       controller_rx_dv;
  logic [7:0] controller_rx_byte;
  logic       controller_spi_cs_n;

  logic       peripheral_rst_l;
  logic       peripheral_tx_dv;
  logic [7:0] peripheral_tx_byte; 
  logic       peripheral_rx_dv;
  logic [7:0] peripheral_rx_byte;
  logic       peripheral_spi_cs_n;

  spi_io spi_if();

  clocking cb @(posedge clk);
    //default input #10 output #1;
    input controller_rx_dv;
    input controller_rx_byte;
    input controller_rx_count;
    input peripheral_rx_dv;
    input controller_tx_ready;
    input peripheral_rx_byte;
    input controller_spi_cs_n;
    output controller_tx_dv;
    output controller_tx_byte;
    output controller_tx_count;
    output controller_rst_l;
    output peripheral_tx_dv;
    output peripheral_tx_byte;
    output peripheral_rst_l;
    output peripheral_spi_cs_n;
  endclocking

  modport tb(clocking cb);

endinterface : spi_board_io

