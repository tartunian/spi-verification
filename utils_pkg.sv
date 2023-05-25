package utils_pkg;

  class debug;

    typedef enum {
      BLACK = 30,
      RED = 31,
      GREEN = 32,
      BROWN = 33,
      BLUE = 34,
      MAGENTA = 35,
      CYAN = 36,
      WHITE = 37
    } displayColor_e;

    `define DEBUG(MSG) \
      case ($sformatf("%m")) \
        "$unit::\\environment::run ", \
        "$unit::\\environment::wrap_up ": $write("%c[0;36m",27); \
        "$unit::\\spi_generator::run ": $write("%c[0;35m",27); \
        "$unit::\\spi_driver::run ", \
        "$unit::\\spi_driver::write ", \
        "$unit::\\spi_driver::write_array ", \
        "$unit::\\spi_driver::trigger_write " : $write("%c[0;32m",27); \
        "$unit::\\spi_monitor::run ": $write("%c[0;31m",27); \
        "$unit::\\spi_scoreboard::run ": $write("%c[0;33m",27); \
        "$unit::\\spi_checker::run ": $write("%c[0;34m",27); \
        default: $write("%c[0;37m",27); \
      endcase \
      debug::debug($sformatf("%s:: %-50s time: %0t", $sformatf("%50s", $sformatf("%m")), MSG, $time));
    `define  DEBUG_INDENT(MSG) \
      repeat(50) begin \
        $write(" "); \
      end \
      debug::debug($sformatf("%s", MSG ));

    static bit enable_output_file = 0;
    static integer output_file;

    static function debug_to_file(string msg);
      if(output_file === 32'bx)
        output_file = $fopen("debug_output.txt", "w");
      $fwrite(output_file, msg);
      $fwrite(output_file,"\n");
    endfunction

    static function debug(string msg);
      $display(msg);
      if(enable_output_file)
        debug_to_file(msg);
    endfunction

    static function close();
      $fclose(output_file);
    endfunction

  endclass

endpackage : utils_pkg

