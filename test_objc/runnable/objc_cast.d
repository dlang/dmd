// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class ObjcObject {
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

// Runtime Support (to be added to druntime):

import objc.runtime;

extern (C)
id _dobjc_dynamic_cast(id obj, Class cls)
{
    id __selector(Class) isKindOfClass = cast(id __selector(Class))"isKindOfClass:";
    if (isKindOfClass(obj, cls))
        return obj;
    return null;
}

extern (C)
id _dobjc_interface_cast(id obj, Protocol p)
{
    id __selector(Protocol) conformsToProtocol = cast(id __selector(Protocol))"conformsToProtocol:";
    if (conformsToProtocol(obj, p))
        return obj;
    return null;
}

