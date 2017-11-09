package;

#if (cs)
import cs.NativeArray;
import cs.types.UInt8;
import cs.system.io.FileStream;
#else
import haxe.io.Bytes;
#end
/**
 * ...
 * @author YellowAfterlife
 */
class DataStream {
	#if (cs)
	private var stream:FileStream;
	private function new(st:FileStream) {
		stream = st;
	}
	public static function write(path:String):DataStream {
		return new DataStream(new FileStream(path, Create, Write, None));
	}
	public static function read(path:String):DataStream {
		return new DataStream(new FileStream(path, Open, Read, None));
	}
	public static function open(path:String, create:Bool):DataStream {
		return new DataStream(new FileStream(path, create ? OpenOrCreate : Open, ReadWrite, None));
	}
	//
	public var position(get, set):Int;
	private inline function get_position():Int {
		return stream.Position.low;
	}
	private inline function set_position(p:Int):Int {
		stream.Position = p;
		return p;
	}
	//
	public var length(get, never):Int;
	private inline function get_length():Int {
		return stream.Length.low;
	}
	//
	public inline function skip(ofs:Int):Void {
		stream.Seek(ofs, Current);
	}
	//
	public inline function readByte():Int {
		return stream.ReadByte();
	}
	public inline function writeByte(b:Int):Void {
		stream.WriteByte(b);
	}
	//
	public inline function close():Void {
		stream.Close();
	}
	private static inline var copyBufSize = 4096;
	private static var copyBuf:NativeArray<UInt8> = new NativeArray(copyBufSize);
	public inline function writeStream(src:DataStream, size:Int) {
		var srcStream = src.stream;
		var buf = copyBuf;
		while (size > 0) {
			var want = copyBufSize;
			if (want > size) want = size;
			var got = srcStream.Read(buf, 0, want);
			if (got == 0) break;
			stream.Write(buf, 0, got);
			size -= got;
		}
	}
	#else
	
	#end
	//
	public function readInt32():Int {
		var b1 = readByte();
		var b2 = readByte();
		var b3 = readByte();
		var b4 = readByte();
		return b1 | (b2 << 8) | (b3 << 16) | (b4 << 24);
	}
	public function writeInt32(x:Int):Void {
		writeByte(x & 0xFF);
		writeByte((x >> 8) & 0xFF);
		writeByte((x >> 16) & 0xFF);
		writeByte(x >>> 24);
	}
	//
	public function readCString(len:Int):String {
		var b = new StringBuf();
		while (--len >= 0) b.addChar(readByte());
		return b.toString();
	}
	//
	public function writeStreamAll(ds:DataStream) {
		writeStream(ds, ds.length - ds.position);
	}
	//
	/**
	 * Realigns and copies an asset section header between two asset packages.
	 */
	public function writeAssetHeader(src:DataStream, outStart:Int, srcStart:Int):Void {
		var out = this;
		var delta = (out.position - outStart) - (src.position - srcStart);
		var count = src.readInt32();
		out.writeInt32(count);
		for (i in 0 ... count) {
			var addr = src.readInt32();
			out.writeInt32(addr + delta);
		}
	}
	
	public function writeZeroes(count:Int):Void {
		while (--count >= 0) writeByte(0);
	}
	//
}
