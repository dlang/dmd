// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() @selector("alloc");
	this() @selector("init");
}

class Test1Object : NSObject {
	int in1;
	int out1;
    
    void test()
    in { in1 += 1; assert(0); } // failure makes overriden in contract is evaluated
    out { out1 += 1; }
    body { }
}

class Test2Object : Test1Object {
	int in2;
	int out2;
    
    override void test()
    in { in2 += 1; }
    out { out2 += 1; }
    body { }
}

void main() {
	Test2Object obj = new Test2Object;
    obj.test();
    assert(obj.in1 == 1);
    assert(obj.in2 == 1);
    assert(obj.out1 == 1);
    assert(obj.out2 == 1);
}
