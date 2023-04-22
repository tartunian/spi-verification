import utils_pkg::*;
import SPI_verification_trANDgen_pkg::*;

class spi_driver;

	mailbox #(Transaction) gen2drv;
	virtual spi_board_io spi_board_if;
	Transaction tr;

	function new(virtual spi_board_io spi_board_if, mailbox #(Transaction) gen2drv);
		this.spi_board_if = spi_board_if;
		this.gen2drv = gen2drv;
	endfunction : new

	task get_tr();
		gen2drv.get(tr);
	endtask

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


	task controller_write();
		foreach(i = this.tr.tx_msgs);
			logic [7:0] write_value = this.tr.tx_msgs[i]
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

	task run();
		
		forever begin	
			gen2drv.get(tr);
			case(tr.tr_type_e)
				controller_w:	controller_write(tr.tx_msgs);
				peripheral_w:	peripheral_write(tr.tx_msgs);
			endcase // tr.tr_type_e
		end

endclass : spi_driver