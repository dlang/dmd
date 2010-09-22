
extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object
}

extern (Objective-C)
interface TestInterfaceBase {
	static void test1();
	static void test2();
}

extern (Objective-C)
interface TestInterface : TestInterfaceBase {
	void test();
	static void test2();
}

class TestObject : NSObject, TestInterface {
}

void main() {
	// runtime initialization will test things
}
