// PLATFORM: osx

extern (Objective-C)
interface ObjcObject {
	this() @selector("init");
	this(int i) @selector("initWithInt:");
}

extern (Objective-C)
class NSObject : ObjcObject {
	this() @selector("init");
	this(int i) @selector("initWithInt:");
}

class TestObject : NSObject {
	this();
	this(int i);
}
