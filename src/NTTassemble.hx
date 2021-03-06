package;
import haxe.ds.Vector;
import sys.FileSystem;
import NativeExtras.*;

/**
 * ...
 * @author YellowAfterlife
 */
class NTTassemble {
	//
	private static inline var part1path = "ntt-1.part";
	private static inline var part2path = "ntt-2.part";
	private static inline var part3path = "ntt-3.part";
	
	private static inline var baseExePath = "nuclearthrone.exe";
	private static inline var baseDataPath = "data.win";
	
	private static inline var modExePath = "NuclearThroneTogether.exe";
	private static inline var modDataPath = "data.ntt";
	
	private static function findDataPath() {
		for (check in [
			baseExePath,
			baseDataPath,
			modDataPath,
		]) if (FileSystem.exists(check)
			&& FileSystem.stat(check).size > 90 * 1024 * 1024 // must be at least 90MB!
		) {
			return check;
		}
		return exit([
			"Couldn't find any game files with assets.",
			"Did you extract the files into the game directory?"
		]);
	}
	//
	private static function pickGame(ask:String):String {
		print([
			ask,
			"1: Nuclear Throne",
			"2: Nuclear Throne Together",
			"0: Exit",
		]);
		return switch (prompt()) {
			case "1".code: baseExePath;
			case "2".code: modDataPath;
			case "0".code: seeYa(); null;
			default: unknown(); null;
		}
	}
	//
	public static function assemble(?outPath:String) {
		if (outPath == null) outPath = modDataPath;
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
			if (outPath == modExePath) {
				print(["Reminder: NTT is now in " + modExePath
					+ " instead of replacing the original game executable."]);
			}
			sys.io.File.copy(part3path, modExePath);
			allGood();
			exit(["All good!"], true);
		}, function(err:String) {
			exit([err]);
		});
		//
		return null;
	}
	//
	static function asciiToWide(s:String):Vector<Int> {
		var r:Vector<Int> = new Vector(s.length << 1);
		for (i in 0 ... s.length) {
			r[i << 1] = s.charCodeAt(i);
			r[(i << 1) + 1] = 0;
		}
		return r;
	}
	public static function patchDataPath(?exePath:String, ?exePath2:String) {
		if (exePath == null) exePath = baseExePath;
		if (exePath2 == null) exePath2 = modExePath;
		Sys.println('Patching $exePath and copying to $exePath2...');
		var a = DataStream.read(exePath);
		if (FileSystem.exists(exePath2)) FileSystem.deleteFile(exePath2);
		var b = DataStream.open(exePath2, true);
		var find = asciiToWide('data.win');
		var findCount = find.length;
		var n = a.length;
		while (a.position < n) {
			var match = true;
			for (i in 0 ... findCount) {
				if (a.position >= n) {
					match = false;
					break;
				}
				var d = a.readByte();
				if (d != find[i]) {
					for (k in 0 ... i) b.writeByte(find[k]);
					b.writeByte(d);
					match = false;
					break;
				}
			}
			if (match) {
				for (d in asciiToWide('data.ntt')) b.writeByte(d);
			}
		}
		a.close();
		b.close();
		Sys.println('OK!');
	}
	public static function preproc(?exePath:String) {
		if (exePath == null) exePath = modDataPath;
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
		if (outPath == null) outPath = baseDataPath;
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
		if (srcPath == null) srcPath = baseDataPath;
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
			case "-ntt-reroute": patchDataPath(args[1], args[2]);
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
			"2: Toggle Steam",
			"0: Exit",
		]);
		switch (prompt()) {
			case "1".code: assemble();
			case "2".code: toggleSteam(pickGame("In what?"));
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
