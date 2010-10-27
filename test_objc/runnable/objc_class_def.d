
extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc();
	NSObject init();
}

import std.c.stdio;

class TestObject : NSObject {
	int val;

//	static void load() { printf("hello load".ptr); }
	static void initialize() { printf("hello initialize"); }
//	static TestObject alloc() { printf("hello alloc"); return null; }
	TestObject init() { printf("init"); return null; }
	TestObject init2() { printf("init2"); return init(); }
}

void main() {
//	NSObject obj1 = NSObject.alloc();
//	obj1.init();
//	assert(obj1 !iMs null);
	
	printf("main");
	NSObject obj2 = TestObject.alloc().init();
	assert(obj2 is null);
}
