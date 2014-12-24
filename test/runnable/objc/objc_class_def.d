// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() @selector("alloc");
	NSObject init() @selector("init");
}

import std.c.stdio;

class TestObject : NSObject {
	int val;

//	static void load() { printf("hello load".ptr); }
	static void initialize() { printf("hello initialize\n"); }
//	static TestObject alloc() { printf("hello alloc"); return null; }
	TestObject init() { printf("init\n"); return null; }
	TestObject init2() { printf("init2\n"); return init(); }
}

void main() {
	NSObject obj1 = NSObject.alloc().init();
	assert(obj1 !is null);
	
	printf("main");
	NSObject obj2 = TestObject.alloc().init();
	assert(obj2 is null);
}
