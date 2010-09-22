
extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc();
	NSObject init();
}

import std.stdio;

class TestObject : NSObject {
	int val;

//	static void load() { writeln("hello load"); }
	static void initialize() { writeln("hello initialize"); }
//	static TestObject alloc() { writeln("hello alloc"); return null; }
	TestObject init() { writeln("init"); return null; }
	TestObject init2() { writeln("init2"); return init(); }
}

void main() {
	NSObject obj1 = NSObject.alloc().init();
	assert(obj1 !is null);
	
	writeln("main");
	NSObject obj2 = TestObject.alloc().init();
	assert(obj2 is null);
}
