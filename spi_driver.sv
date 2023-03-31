import utils_pkg::*;

class spi_driver;

	virtual spi_board_io spi_board_if;

	function new(virtual spi_board_io spi_board_if);
		this.spi_board_if = spi_board_if;
	endfunction : new


	task setup_controller_write(logic [7:0] write_value);
		this.spi_board_if.controller_tx_byte <= write_value;
		this.spi_board_if.controller_tx_dv <= 1'b1;
	endtask


	task setup_peripheral_write(logic [7:0] write_value);
		this.spi_board_if.peripheral_tx_byte <= write_value;
		this.spi_board_if.peripheral_tx_dv <= 1'b1;
	endtask


	task trigger_write();
		this.spi_board_if.controller_tx_dv <= 1'b0;
		this.spi_board_if.peripheral_tx_dv <= 1'b0;
	endtask


	task controller_write(logic [7:0] write_value);
		@(posedge this.spi_board_if.clk);
		setup_controller_write(write_value);
		setup_peripheral_write(8'h00);
		
		`DEBUG($sformatf("put 0x%h", write_value), 0);

		@(posedge this.spi_board_if.clk);
		trigger_write();
		
		@(posedge this.spi_board_if.clk);
		@(posedge this.spi_board_if.controller_tx_ready);

		
		
	endtask : controller_write	


	task peripheral_write(logic [7:0] write_value);
		@(posedge this.spi_board_if.clk);
		setup_controller_write(8'h00);
		setup_peripheral_write(write_value);

		`DEBUG($sformatf("put 0x%h", write_value), 0);
		
		@(posedge this.spi_board_if.clk);
		trigger_write();
		
		@(posedge this.spi_board_if.clk);
		@(posedge this.spi_board_if.controller_tx_ready);


		
	endtask : peripheral_write

endclass : spi_driver