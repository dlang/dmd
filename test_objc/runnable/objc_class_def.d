
extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc();
	NSObject init();
}

class TestObject : NSObject {
	int val;
}

void main() {
	NSObject obj1 = TestObject.alloc().init();
	assert(obj1 !is null);
}
