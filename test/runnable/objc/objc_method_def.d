// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

import std.c.stdio;

extern (Objective-C)
class NSObject {
	void* isa;
	
	static NSObject alloc() @selector("alloc");
	NSObject init();
}

class TestObject : NSObject {
	void test(immutable(char)* param) {
		assert(param[0] == 'h', "expects 'hello' param, found something else (probably the selector)");
        assert((cast(ubyte*)_cmd)[0] == 't', "expects 'test' _cmd (implicit selector variable)");
	}
}

void main() {
	TestObject o = cast(TestObject)cast(void*)TestObject.alloc().init();
	o.test("hello".ptr);
}