// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
interface ObjcObject {
	static ObjcObject alloc() [alloc];
	static ObjcObject alloc(void* zone) [allocWithZone:];
}

extern (Objective-C)
class NSObject : ObjcObject {
	void* isa; // pointer to class object

	this() [init];
}

extern (Objective-C)
interface TestInterface {}

class TestObject : NSObject, TestInterface {}

void main() {
	NSObject a = new TestObject;
    TestObject b = cast(TestObject)a;
    TestInterface c = cast(TestInterface)a;
}
