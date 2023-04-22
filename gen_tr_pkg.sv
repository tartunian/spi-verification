  /*
  `ifndef 
    `define SV_RAND_CHECK(r) \
      do begin \
        if (!(r)) begin \
          $display("%s:%0d: Randomization failed \"%s\"", \
          `__FILE__, `__LINE__, `"r`"); \
          $finish; \
        end \
      end while (0)
  `endif
  */
package SPI_verification_trANDgen_pkg;


  // typedef virtual spi_io.tb ioTB; // Specified in example, not sure if we need this at the moment...

  class Transaction; 
    // The thing we transact in SPI are tx and rx messages.
    // I imagine there's going to be a controller transaction and a peripheral transaction class.
    rand int num_messages; // here we can use num_messages to vary the number of bytes we send/receive
    constraint c_num_messages {
    num_messages > 0; 
    num_messages < 10;      
    }
    logic [7:0] tx_msgs []; // the content of the message can be randomized, but the interface we test limits tx and rx to be packaged as bytes.
    logic [7:0] rx_msgs []; // rx messages are not generated, they received! no need to randomize these, but their size must match the number of tx msgs.
    logic [7:0] goldenRef []; // depending on what we do, this could just copy the info of tx_msgs from the controller, or could hold the expected responses of the periph.
    typedef enum {controller_w, peripheral_w} tr_type_e;
    rand tr_type_e msg_type;

    bit last_tr;
    // Do we want to explore defining the peripheral's response table? Don't know if that's written into 
    // the SPI modules capability...
  endclass: Transaction
    
  class Generator;
    Transaction tr;
    mailbox #(Transaction) gen2scr;
    mailbox #(Transaction) gen2drv;
    int numTrs;

    function new( // define the constructor to take mailboxes and the number of transactions desired as arguments
      mailbox #(Transaction) gen2scr,
      mailbox #(Transaction) gen2drv,
      int numTrs
      );
      this.gen2scr = gen2scr;
      this.gen2drv = gen2drv;
      this.numTrs = numTrs;
    endfunction : new

    function automatic void gen_rand_tr();
      this.tr = new();
      this.tr.randomize();
      this.tr.tx_msgs = new[this.tr.num_messages];
      this.tr.rx_msgs = new[this.tr.num_messages];
      this.tr.goldenRef = new[this.tr.num_messages];
      foreach(this.tr.tx_msgs[i])begin
        this.tr.tx_msgs[i] = $urandom_range(0,255);
        this.tr.goldenRef[i] = this.tr.tx_msgs[i];
      end
    endfunction

    task run();
      for (int i = 0; i < this.numTrs; i = i + 1) begin
        gen_rand_tr();
        this.tr.last_tr = i == (this.numTrs - 1);
        gen2drv.put(this.tr);
        gen2scr.put(this.tr);
      end
    endtask : run

endclass : Generator

endpackage : SPI_verification_trANDgen_pkg


