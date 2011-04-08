// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() [alloc];
	this() [init];
}

class Test1Object : NSObject {
	int invariant1;
    int preinit = 1; // test that preinit doesn't call invariant
    
    void test() { test2(); }
    private void test2() { }
    
    this() { printf("this()\n"); }
    
    invariant() {
        printf("invariant1\n");
        invariant1 += 1;
    }
}

class Test2Object : Test1Object {
	int invariant2;
    int callsToTest2;
    
    void test() { super.test(); }
    
    invariant() {
        printf("invariant2\n");
        invariant2 += 1;
    }
}

import std.c.stdio;
void main() {
	Test2Object obj = new Test2Object;
    assert(obj.invariant2 == 1);
    assert(obj.invariant1 == 1);
    
    obj.test();
    assert(obj.invariant2 == 5);
    assert(obj.invariant1 == 5);
    
    assert(obj);
    assert(obj.invariant2 == 6);
    assert(obj.invariant1 == 6);
}
