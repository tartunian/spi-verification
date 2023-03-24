`define HALF_CLK_PRD	10

package utils_pkg;

	class debug;

		`define DEBUG(msg, lvl) \
			utils_pkg::debug::debug($sformatf("%m ==> %s", msg), lvl);

		static bit enable = 1;
		static bit enable_output_file = 1;
		static integer output_file;

		static function debug_to_file(string msg);
			if(output_file === 32'bx)
				output_file = $fopen("debug_output.txt", "w");
			$fwrite(output_file, msg);
			$fwrite(output_file,"\n");
		endfunction

		static function debug(string msg, int level);
			if(enable) begin
				string _msg = msg;
				repeat (level) _msg = { "\t", _msg };
				$display(_msg);
				if(enable_output_file)
					debug_to_file(_msg);
			end
		endfunction

		static function close();
			$fclose(output_file);
		endfunction


	endclass

endpackage : utils_pkg