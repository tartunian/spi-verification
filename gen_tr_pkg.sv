package SPI_verification_trANDgen_pkg;
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

  // typedef virtual spi_io.tb ioTB; // Specified in example, not sure if we need this at the moment...

  class Transaction; 
    // The thing we transact in SPI are tx and rx messages.
    // I imagine there's going to be a controller transaction and a peripheral transaction class.
    rand int num_messages; // here we can use num_messages to vary the number of bytes we send/receive
    rand logic [7:0] tx_msgs []; // the content of the message can be randomized, but the interface we test limits tx and rx to be packaged as bytes.
    logic [7:0] rx_msgs []; // rx messages are not generated, they received! no need to randomize these, but their size must match the number of tx msgs.
    logic [7:0] goldenRef []; // depending on what we do, this could just copy the info of tx_msgs from the controller, or could hold the expected responses of the periph.
    tx_msgs = new(num_messages);
    rx_msgs = new(num_message);

    bit last_tr;
    enum {controller_r, controller_w, peripheral_r, peripheral_w} tr_type_e;

    goldenRef = new(num_messages);
    // Do we want to explore defining the peripheral's response table? Don't know if that's written into 
    // the SPI modules capability...

    class Generator;
      Transaction tr;
      mailbox #(Transaction) gen2scr;
      mailbox #(Transaction) gen2drv;
      int numTrs;

      function new // define the constructor to take mailboxes and the number of transactions desired as arguments
      ( mailbox #(Transaction) gen2scr,
        mailbox #(Transaction) gen2drv,
        int numTrs
      );
        this.gen2scr = gen2scr;
        this.gen2drv = gen2drv;
        this.numTrs = numTrs;
      endfunction : new

      function void gen_rand_tr();
        tr = new()
        `SV_RAND_CHECK(tr.randomize());
      endfunction

      task run();
        for (int i = 0; i < num_trs; i = i + 1) begin
        gen_rand_tr();
        tr.last_tr = i == (num_trs - 1);
        gen2drv.put(tr);
        gen2scr.put(tr);
      end
    endtask : run

  endclass : Generator



