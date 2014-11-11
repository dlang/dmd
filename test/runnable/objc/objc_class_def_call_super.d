// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() @selector("alloc");
	NSObject init() @selector("init");
}

class TestObject : NSObject {
    static TestObject alloc() { return cast(TestObject)cast(void*)super.alloc(); }
	override TestObject init() { return cast(TestObject)super.init(); }
}

void main() {
	NSObject obj2 = TestObject.alloc().init();
	assert(obj2 !is null);
}
