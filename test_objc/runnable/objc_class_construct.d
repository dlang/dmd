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

class TestObject : NSObject {
	int val;
    int num = 33;
    
    this() { this(10); }
    this(int initVal) { val = initVal; }
}

void main() {
	TestObject obj1 = new TestObject;
	obj1._dobjc_preinit();
	assert(obj1 !is null);
    assert(obj1.val == 10);
    assert(obj1.num == 33);
    
	TestObject obj2 = new(null) TestObject;
	obj2._dobjc_preinit();
	assert(obj2 !is null);
    assert(obj2.val == 10);
    assert(obj2.num == 33);
    
	TestObject obj3 = new TestObject(22);
	obj3._dobjc_preinit();
	assert(obj3 !is null);
    assert(obj3.val == 22);
    assert(obj3.num == 33);
}
