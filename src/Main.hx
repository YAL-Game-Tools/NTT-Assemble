package;
import haxe.io.Eof;
import haxe.io.Input;
import sys.io.File;
import sys.io.FileInput;
import haxe.io.BytesInput;
import sys.io.FileSeek;
import Macro.*;

/**
 * ...
 * @author YellowAfterlife
 */
class Main {
	
	static function exit(s:String) {
		Sys.exit(1);
		return null;
	}
	
	static function status(s:String) {
		Sys.println(s);
	}
	
	#if (sys)
	
	#end
	
	static function main() {
		var args = Sys.args();
		if (args.length > 0) {
			
		} else assemble();
	}
	
}
