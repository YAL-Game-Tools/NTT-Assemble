package;
import sys.FileSystem;

/**
 * ...
 * @author YellowAfterlife
 */
class NTTassemble {
	//
	private static var getcOnExit:Bool = false;
	private static inline var part1path = "nuclearthrone-1.part";
	private static inline var part2path = "nuclearthrone-2.part";
	private static inline var ntPath = "nuclearthrone.exe";
	private static inline var nttPath = "NuclearThroneTogether.exe";
	private static inline var dataPath = "data.win";
	private static function findDataPath() {
		for (check in [
			dataPath,
			ntPath,
			nttPath,
		]) if (FileSystem.exists(check)) {
			return check;
		}
		return exit([
			"Couldn't find any game files with assets.",
			"Did you extract the files into the game directory?"
		]);
	}
	//
	private static function print(lines:Array<String>) {
		for (line in lines) Sys.println(line);
	}
	private static function prompt() {
		Sys.print("> ");
		var c = Sys.getChar(true);
		Sys.println("");
		return c;
	}
	private static function allGood() {
		exit(["All good!"], true);
	}
	private static function seeYa() {
		Sys.println("See you later!");
		Sys.exit(0);
	}
	private static function unknown() {
		exit(["That's not a known option."]);
	}
	private static function pickGame(ask:String):String {
		print([
			ask,
			"1: Nuclear Throne",
			"2: Nuclear Throne Together",
			"0: Exit",
		]);
		return switch (prompt()) {
			case "1".code: ntPath;
			case "2".code: nttPath;
			case "0".code: seeYa(); null;
			default: unknown(); null;
		}
	}
	//
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
	//
	public static function assemble(?outPath:String) {
		if (outPath == null) outPath = nttPath;
		Sys.println("Looking for files...");
		//
		var srcPath = findDataPath();
		var sources:Array<DataFile> = [];
		for (path in [srcPath, part1path, part2path]) sources.push(openFile(path));
		//
		var out = writeStream(outPath);
		//
		DataFile.assemble(out, sources[0], sources[1], sources[2], function(appid) {
			out.close();
			if (appid != 0 && !FileSystem.exists("steam_appid.txt")) {
				sys.io.File.saveContent("steam_appid.txt", Std.string(appid));
			}
			if (outPath == nttPath) {
				print(["Reminder: NTT is now in " + nttPath
					+ " instead of replacing the original game executable."]);
			}
			allGood();
			exit(["All good!"], true);
		}, function(err:String) {
			exit([err]);
		});
		//
		return null;
	}
	//
	public static function preproc(?exePath:String) {
		if (exePath == null) exePath = nttPath;
		var file = openFile(exePath);
		file.loadAndSeek("AUDO", function(_) {
			var input = file.stream;
			var audoLen = input.readInt32();
			var audoPos = input.position;
			//
			var part1 = DataStream.write(part1path);
			input.position = 0;
			part1.writeStream(input, audoPos);
			part1.close();
			//
			var part2 = DataStream.write(part2path);
			input.position = audoPos + audoLen;
			part2.writeStreamAll(input);
			part2.close();
			//
			input.close();
			allGood();
		}, function(s) {
			exit(["Couldn't find assets in " + exePath + ": " + s]);
		});
	}
	//
	public static function dataExport(path:String, ?outPath:String) {
		if (path == null) exit(["Expected an executable' name"]);
		if (outPath == null) outPath = dataPath;
		var out = writeStream(outPath);
		openFile(path).extractAssets(out, function(_) {
			out.close();
			allGood();
		}, function(s) {
			exit(["Couldn't export assets: " + s]);
		});
	}
	//
	public static function dataImport(path:String, ?srcPath:String) {
		if (srcPath == null) srcPath = dataPath;
		var file = openFile(path, true);
		file.replaceAssets(readStream(srcPath), function(_) {
			file.stream.close();
			allGood();
		}, function(s) {
			exit(["Couldn't replace assets: " + s]);
		});
	}
	//
	public static function toggleSteam(path:String, ?appid:Int) {
		var file = openFile(path, true);
		file.toggleSteam(function(on) {
			file.stream.close();
			print(["Steam features are now " + (on ? "en" : "dis") + "abled."]);
			allGood();
		}, function(s) {
			exit(["Couldn't toggle: " + s]);
		}, appid);
	}
	//
	public static function toggleOffline(path:String) {
		var file = openFile(path, true);
		file.toggleOffline(function(on) {
			file.stream.close();
			print([on
				? "Offline mode enabled: No online features or replays, but higher performance."
				: "Offline mode disabled: Online features and replays, but lower performance."
			]);
			allGood();
		}, function(s) {
			exit(["Couldn't toggle: " + s]);
		});
	}
	//
	public static function showHelp(term:String) {
		if (term.charAt(0) == "-") term = term.substring(1);
		if (term.charAt(0) == "-") term = term.substring(1);
		switch (term) {
			case "assemble": exit([
				"Use: NTT-Assemble -assemble",
				"Or: NTT-Assemble -assemble NuclearThroneTogether.exe",
				'Combines $part1path, $part2path, and .win/.exe into a new executable.',
				"For producing your own .part files, do -help preproc"
			]);
			case "export": exit([
				"Use: NTT-Assemble -export nuclearthrone.exe",
				"Or: NTT-Assemble -export nuclearthrone.exe mydata.win",
				"Extracts the assets-file from a GM executable.",
				"Most of the tools for modding GM games can't work with executables,",
				"so -import/-export are required for that.",
			]);
			case "import": exit([
				"Use: NTT-Assemble -import nuclearthrone.exe",
				"Or: NTT-Assemble -import nuclearthrone.exe mydata.win",
				"Replaces the assets-file in a GM executable with a provided one.",
				"The size of the new file must be the same as the packed one.",
			]);
			case "ntt-offline": exit([
				"Use: NTT-Assemble -ntt-offline NuclearThroneTogether.exe",
				"Toggles offline mode for Nuclear Throne Together.",
				"This is via a compile-time flag that breaks determinism,",
				"but speeds up collision checking, allowing game to perform better.",
			]);
			case "ntt-steamapi": exit([
				"Use: NTT-Assemble -ntt-steamapi NuclearThroneTogether.exe",
				"Or: NTT-Assemble -ntt-steamapi NuclearThroneTogether.exe 242680",
				"Toggles Steam features (overlay/achievements/Steam P2P multiplayer).",
				"If second argument is provided, uses a different App ID.",
				"(if you want to use this for other games)",
			]);
			default: exit(["No additional information is available about " + term]);
		}
	}
	//
	public static function procArgs(args:Array<String>) {
		if (args[0].substring(0, 2) == "--") args[0] = args[0].substring(1);
		switch (args[0]) {
			case "-assemble": assemble(args[1]);
			case "-preproc": preproc(args[1]);
			case "-export": dataExport(args[1], args[2]);
			case "-import": dataImport(args[1], args[2]);
			case "-ntt-offline": toggleOffline(args[1]);
			case "-ntt-steamapi": toggleSteam(args[1]);
			case "-help": {
				if (args[1] != null) {
					showHelp(args[1]);
				} else exit([
					"Supported options:",
					"-help: Show this text",
					"-assemble: Assemble a new executable from .part+.exe/.win",
					"-export: Extract a data.win file from a GM executable",
					"-import: Insert an updated data.win file to a GM executable",
					"-ntt-offline: Toggle offline mode for NTT",
					"-ntt-steamapi: Toggle Steam features for NT/NTT",
					"For more information about something specific, try -help <command>",
				]);
			};
			default: {
				exit([args[0] + " is not a known command"]);
			};
		}
	}
	//
	public static function interactive() {
		getcOnExit = true;
		print([
			"Hello! What would you like to do?",
			"1: Install Nuclear Throne Together",
			"2: Extract data.win (for messing with)",
			"3: Replace data.win (after messing with)",
			"4: Toggle Steam",
			"5: Toggle offline mode",
			"0: Exit",
		]);
		switch (prompt()) {
			case "1".code: assemble();
			case "2".code: dataExport(pickGame("From where?"));
			case "3".code: dataImport(pickGame("To where?"));
			case "4".code: toggleSteam(pickGame("In what?"));
			case "5".code: toggleOffline(nttPath);
			case "0".code: seeYa(); return;
			default: unknown(); return;
		}
	}
	public static function main() {
		var args = Sys.args();
		if (args.length > 0) {
			procArgs(args);
		} else {
			interactive();
		}
	}
	//
}
