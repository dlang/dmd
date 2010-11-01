
import std.c.stdio;

extern (Objective-C)
class NSObject {
	void* isa;
	
	static NSObject alloc();
	static NSObject allocWithZone(void* zone);
	NSObject init();
}

int globalVar;

class TestObject : NSObject {
	int memberVar;
	
	void test() {
		assert(memberVar == 0);
		memberVar = 2;
		globalVar = 4;
	}
}

void main() {
	TestObject o = cast(TestObject)cast(void*)TestObject.alloc().init();
	o.test();
	assert(o.memberVar == 2);
	assert(globalVar == 4);
}