
extern (Objective-C)
extern class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc();
	NSObject init();
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
	void test1z() {}
}

void main() {
	auto o = TestObject.alloc().init();
	// runtime initialization will test things
}
