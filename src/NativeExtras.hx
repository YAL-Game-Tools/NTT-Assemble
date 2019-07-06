package;
import sys.FileSystem;

/**
 * ...
 * @author YellowAfterlife
 */
class NativeExtras {
	public static var getcOnExit:Bool = false;
	//
	public static function print(lines:Array<String>) {
		for (line in lines) Sys.println(line);
	}
	public static function prompt() {
		Sys.print("> ");
		var c = Sys.getChar(true);
		Sys.println("");
		return c;
	}
	public static function allGood() {
		exit(["All good!"], true);
	}
	public static function seeYa() {
		Sys.println("See you later!");
		Sys.exit(0);
	}
	public static function unknown() {
		exit(["That's not a known option."]);
	}
	public static function exit<T>(details:Array<String>, ok:Bool = false):T {
		print(details);
		if (getcOnExit) {
			Sys.println("Press any key to exit.");
			Sys.getChar(false);
		}
		Sys.exit(ok ? 0 : 1);
		return null;
	}
	public static function openFile(path:String, rw:Bool = false):DataFile {
		if (!FileSystem.exists(path)) {
			return exit([
				path + " does not exist.",
				"Make sure that you have extracted all files?",
			]);
		} else try {
			var stream = rw ? DataStream.open(path, false) : DataStream.read(path);
			return new DataFile(path, stream);
		} catch (err:Dynamic) {
			return exit([
				"Couldn't open " + path + " for reading: " + err
			]);
		}
	}
	public static function readStream(path:String):DataStream {
		if (!FileSystem.exists(path)) {
			return exit([
				path + " does not exist.",
				"Make sure that you have extracted all files?",
			]);
		} else try {
			return DataStream.read(path);
		} catch (err:Dynamic) {
			return exit([
				"Couldn't open " + path + " for reading: " + err
			]);
		}
	}
	public static function writeStream(path:String):DataStream {
		try {
			return DataStream.write(path);
		} catch (err:Dynamic) {
			return exit([
				"Couldn't open " + path + " for writing: " + err,
				"Make sure that it's not in use (e.g. game running in background)?"
			]);
		}
	}
}
