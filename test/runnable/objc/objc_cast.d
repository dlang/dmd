// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
interface ObjcObject {
	static ObjcObject alloc() @selector("alloc");
	static ObjcObject alloc(void* zone) @selector("allocWithZone:");
}

extern (Objective-C)
class NSObject : ObjcObject {
	void* isa; // pointer to class object

	this() @selector("init");
}

extern (Objective-C)
interface TestInterface {}

class TestObject : NSObject, TestInterface {}

void main() {
	NSObject a = new TestObject;
    TestObject b = cast(TestObject)a;
    TestInterface c = cast(TestInterface)a;
}
