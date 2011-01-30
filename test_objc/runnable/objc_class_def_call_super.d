// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc();
	NSObject init();
}

class TestObject : NSObject {
    static TestObject alloc() { return cast(TestObject)cast(void*)super.alloc(); }
	TestObject init() { return super.init(); }
}

void main() {
	NSObject obj2 = TestObject.alloc().init();
	assert(obj2 !is null);
}
