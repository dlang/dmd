
import std.c.stdio;

extern (Objective-C)
class NSObject {
	void* isa;
	
	static NSObject alloc();
	static NSObject allocWithZone(void* zone);
	NSObject init();
}

class TestObject : NSObject {
	void test(immutable(char)* param) {
		assert(param[0] == 'h', "expects 'hello' param, found something else (probably the selector)");
	}
}

void main() {
	TestObject o = cast(TestObject)cast(void*)TestObject.alloc().init();
	o.test("hello".ptr);
}