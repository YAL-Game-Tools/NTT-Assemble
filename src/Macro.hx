package;

/**
 * ...
 * @author YellowAfterlife
 */
class Macro {
	public static macro function chunk32m(s:String) {
		return macro $v{chunk32(s)};
	}
	public static function chunk32(chnk:String):Int {
		var r:Int = 0;
		for (i in 0 ... chnk.length) {
			r |= chnk.charCodeAt(i) << (i * 8);
		}
		return r;
	}
}
