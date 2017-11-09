package;

/**
 * Not quite promises
 * @author YellowAfterlife
 */
class Task {
	public static function next<T, A, B>(func:TaskCb<A>->TaskCb<B>->T->Void,
		done:TaskCb<A>, fail:TaskCb<B>,
		val:T, ?msg:String
	):Void {
		#if (sys)
		if (msg != null) Sys.println(msg + "...");
		try {
			func(done, fail, val);
		} catch (x:Dynamic) {
			Sys.println("An error occurred: " + x);
			fail(null);
		}
		#else
		throw "todo";
		#end
	}
}
