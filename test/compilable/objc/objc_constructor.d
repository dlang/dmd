// PLATFORM: osx

extern (Objective-C)
interface ObjcObject {
	this() [init];
	this(int i) [initWithInt:];
}

extern (Objective-C)
class NSObject : ObjcObject {
	this() [init];
	this(int i) [initWithInt:];
}

class TestObject : NSObject {
	this();
	this(int i);
}
