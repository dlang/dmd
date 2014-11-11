// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() @selector("alloc");
	this() @selector("init");
}

int invariant1;

class Test1Object : NSObject {
    int preinit = 1; // test that preinit doesn't call invariant
    
    void test() { test2(); }
    private void test2() { }
    
    this() { printf("this()\n"); }
    
    invariant() {
        printf("invariant1\n");
        invariant1 += 1;
    }
}

int invariant2;

class Test2Object : Test1Object {
    int callsToTest2;
    
    override void test() { super.test(); }
    
    invariant() {
        printf("invariant2\n");
        invariant2 += 1;
    }
}

import std.c.stdio;
void main() {
	Test2Object obj = new Test2Object;
    assert(invariant2 == 1);
    assert(invariant1 == 1);
    
    obj.test();
    assert(invariant2 == 5);
    assert(invariant1 == 5);
    
    assert(obj);
    assert(invariant2 == 6);
    assert(invariant1 == 6);
}
