// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() [alloc];
	NSObject init() [init];
}

extern (Objective-C)
interface TestInterfaceBase {
	void test1z();
	static void test2z();
}

extern (Objective-C)
interface TestInterface : TestInterfaceBase {
	void testz();
	static void test22z();
}

class TestObject : NSObject, TestInterface {
	void test() {}
	static void test2z() {}
	TestObject init() { return null; }
}

void main() {
	auto o = TestObject.alloc().init();
	// runtime initialization will test things
}
