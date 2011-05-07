// Note: below is a crappy way to compile and link objc_code/objc_exception.m

// REQUIRED_ARGS: -L-framework -LCocoa -L-lobjc runnable/objc_code/objc_exception.o $(gcc -m32 runnable/objc_code/objc_exception.m -c -o runnable/objc_code/objc_exception.o)
// POST_SCRIPT: rm runnable/objc_code/objc_exception.o

extern (Objective-C)
class NSObject {
	void* isa; // pointer to class object

	static NSObject alloc() [alloc];
	this() [init];
}

extern (Objective-C)
pragma (objc_takestringliteral)
class NSString {
    private this();
}

extern (Objective-C)
class NSDictionary {
    private this();
}

extern (Objective-C)
class NSException : NSObject {
    this(NSString name, NSString reason, NSDictionary userInfo)
        [initWithName:reason:userInfo:];
    
    @property NSString name() [name];
    @property NSString reason() [reason];
    @property NSDictionary userInfo() [userInfo];
}

extern (Objective-C) void _throwObjc() {
    throw new NSException("Hello!", "Testing.", null);
}

extern (Objective-C) void _test_throw();
extern (Objective-C) bool _test_catch(void function());
extern (Objective-C) void _test_finally(void function(), ref bool);

import std.stdio;

void test1() {
    bool caught;
    bool finalized;
    bool notthrown;
    try {
        _throwObjc();
        notthrown = true;
    } catch (NSException e) {
        caught = true;
    } finally {
        finalized = true;
    }
    
    assert(notthrown == false);
    assert(caught == true);
    assert(finalized == true);
}

void test2() {
    bool caught;
    bool finalized;
    bool notthrown;
    try {
        _test_throw();
        notthrown = true;
    } catch (NSException e) {
        caught = true;
    } finally {
        finalized = true;
    }
    
    assert(notthrown == false);
    assert(caught == true);
    assert(finalized == true);
}

void test3() {
    bool caught = _test_catch(&_throwObjc);
    assert(caught);
}

void test4() {
    bool caught;
    bool objcfinalized;
    bool finalized;
    bool notthrown;
    try {
        try
            _test_finally(&_throwObjc, objcfinalized);
        finally
            finalized = true;
        notthrown = true;
    } catch (NSException e) {
        caught = true;
    }
    
    assert(notthrown == false);
    assert(objcfinalized == true);
    assert(caught == true);
    assert(finalized == true);
}


void main() {
    test1();
    test2();
    test3();
    test4();
}
