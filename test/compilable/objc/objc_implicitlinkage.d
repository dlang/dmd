
extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc();
	NSObject init();
}

class TestObject : NSObject {
	int val;
	
	NSObject init() { return null; }
}
