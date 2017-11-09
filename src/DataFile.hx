package;
import Macro.*;
import haxe.io.Eof;

/**
 * ...
 * @author YellowAfterlife
 */
class DataFile {
	//
	public var name:String;
	public var stream:DataStream;
	/** -1: not measured, -2: broken, _: <offset> */
	public var start:Int = -1;
	public var size:Int = 0;
	public static inline var steamAppID = 242680;
	
	/** Pointing to position after chunk name and before the size */
	public var chunks:Map<String, Int> = new Map();
	//
	public function new(name:String, stream:DataStream) {
		this.name = name;
		this.stream = stream;
	}
	//
	public function seekChunk(name:String):Bool {
		if (chunks.exists(name)) {
			stream.position = chunks.get(name);
			return true;
		} else return false;
	}
	//
	public function loadAndSeek(name:String, done:TaskCb<DataFile>, fail:TaskCb<String>) {
		loadChunks(function(file:DataFile) {
			if (chunks.exists(name)) {
				stream.position = chunks.get(name);
				done(file);
			} else fail("Couldn't find chunk " + name + " in " + this.name + " (wrong file?)");
		}, fail);
	}
	//
	public function loadChunks(done:TaskCb<DataFile>, fail:TaskCb<String>) {
		inline function amiss(fail:TaskCb<String>, file:DataFile, x:Dynamic) {
			fail("Couldn't find assets in " + file.name + (x != null ? ": " + x : ""));
		}
		if (start >= 0) {
			done(this);
		} else if (start == -2) {
			amiss(fail, this, null);
		} else Task.next(function(done:TaskCb<DataFile>, fail:TaskCb<String>, file:DataFile) {
			try {
				var input = file.stream;
				input.position = 0;
				while (true) {
					//
					if (input.readInt32() != chunk32m("FORM")) continue;
					var data_size = input.readInt32();
					var data_start = input.position;
					//
					if (input.readInt32() != chunk32m("GEN8")) continue;
					var gen8_size = input.readInt32();
					input.skip(gen8_size);
					//
					file.size = data_size;
					file.start = data_start;
					break;
				}
				//
				chunks["FORM"] = file.start - 4;
				chunks["GEN8"] = file.start;
				var data_end = file.start + file.size;
				while (input.position < data_end) {
					var chName = input.readCString(4);
					chunks.set(chName, input.position);
					input.skip(input.readInt32());
				}
				//
			} catch (x:Dynamic) {
				file.start = -2;
				amiss(fail, file, x);
				return;
			}
			done(file);
		}, done, fail, this, "Looking for assets in " + this.name);
	}
	//
	public function extractAssets(out:DataStream, done:TaskCb<Bool>, fail:TaskCb<String>) {
		loadAndSeek("FORM", function(file:DataFile) {
			Task.next(function(done, fail, file:DataFile) {
				file.stream.skip( -4);
				out.writeStream(file.stream, file.size + 8);
				done(true);
			}, done, fail, file, "Copying assets");
		}, fail);
	}
	//
	public function replaceAssets(src:DataStream, done:TaskCb<Bool>, fail:TaskCb<String>) {
		loadAndSeek("FORM", function(file:DataFile) {
			Task.next(function(done, fail, file:DataFile) {
				var size0 = file.stream.readInt32() + 4;
				var size1 = src.length;
				if (size0 == size1) {
					file.stream.skip( -8);
					file.stream.writeStream(src, size1);
					done(true);
				} else fail('Asset file length must match (current: $size0, new: $size1)');
			}, done, fail, file, "Copying assets");
		}, fail);
	}
	//
	public function toggleSteam(done:TaskCb<Bool>, fail:TaskCb<String>, ?appid1:Int) {
		if (appid1 == null) appid1 = steamAppID/* NT */;
		loadAndSeek("GEN8", function(file:DataFile) {
			var stream = file.stream;
			stream.skip(120);
			var appid = stream.readInt32();
			appid = appid != appid1 ? appid1 : 0;
			stream.skip( -4);
			stream.writeInt32(appid);
			done(appid != 0);
		}, fail);
	}
	//
	public function toggleOffline(done:TaskCb<Bool>, fail:TaskCb<String>) {
		loadAndSeek("GEN8", function(file:DataFile) {
			var stream = file.stream;
			stream.skip(15);
			var flags = stream.readByte();
			var fcs = 0x4;
			flags = (flags & fcs != 0) ? (flags & ~fcs) : (flags | fcs);
			stream.skip( -1);
			stream.writeByte(flags);
			done(flags & fcs != 0);
		}, fail);
	}
	//
	public static function assemble(
		out:DataStream, orig:DataFile, part1:DataFile, part2:DataFile,
		done:TaskCb<Int>, fail:TaskCb<String>
	):Void {
		var steps:Array<Dynamic->Void> = [];
		var preAudoLen:Int = 0;
		var appid:Int = 0;
		steps[0] = function preparePart1(_) {
			part1.loadChunks(steps[1], fail);
		};
		steps[1] = function prepareData(_) {
			orig.loadChunks(steps[2], fail);
		};
		steps[2] = function copyPart1(_) {
			if (!orig.chunks.exists("AUDO")) {
				fail(orig.name + " does not contain audio assets (wrong file?).");
			} else if (!part1.chunks.exists("AUDO")) {
				fail(part1.name + " does not contain audio assets (wrong file?).");
			} else Task.next(function(done, fail, _) {
				var p1input = part1.stream;
				var p0input = orig.stream;
				// copy from start and till Steam App ID:
				p1input.position = 0;
				out.writeStream(p1input, part1.chunks["GEN8"] + 120);
				p1input.readInt32(); // (skip Steam App ID)
				// copy Steam App ID from original executable:
				p0input.position = orig.chunks["GEN8"] + 120;
				appid = p0input.readInt32();
				out.writeInt32(appid);
				// copy the stuff up to AUDO chunk
				out.writeStream(p1input, part1.chunks["AUDO"] - p1input.position);
				preAudoLen = p1input.readInt32();
				out.writeInt32(preAudoLen);
				//
				done(null);
			}, steps[3], fail, null, "Copying new things");
		}
		steps[3] = function copyAudio(_) {
			Task.next(function(done, fail, _) {
				var origInput = orig.stream;
				origInput.position = orig.chunks["AUDO"];
				var origAudoLen = origInput.readInt32();
				var origAudoEnd = origInput.position + origAudoLen;
				out.writeAssetHeader(origInput, part1.start, orig.start);
				out.writeStream(origInput, origAudoEnd - origInput.position);
				if (preAudoLen >= origAudoLen) {
					out.writeZeroes(preAudoLen - origAudoLen);
					done(null);
				} else {
					fail("Can't patch - audio section doesn't fit. "
						+ "A newer NTT build or an older game build may be needed."
					);
				}
			}, steps[4], fail, null, "Copying audio files");
		};
		steps[4] = function copyPart2(_) {
			Task.next(function(done, fail, _) {
				out.writeStreamAll(part2.stream);
				done(appid);
			}, steps[5], fail, null, "Copying other things");
		}
		steps[5] = done;
		steps[0](null);
	}
	//
}
