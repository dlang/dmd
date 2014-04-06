// Note: below is a crappy way to compile and link objc_code/objc_exception.m

// REQUIRED_ARGS: -L-framework -LCocoa -L-lobjc runnable/objc_code/objc_exception.o $(gcc -m$MODEL runnable/objc_code/objc_exception.m -c -o runnable/objc_code/objc_exception.o)
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

extern (Objective-C) void throwD() {
    throw new Exception("This is a D exception!");
}

extern (Objective-C) void throwObjc() {
    throw new NSException("Hello!", "Testing.", null);
}

extern (Objective-C) void test_throw();
extern (Objective-C) bool test_catch(void function());
extern (Objective-C) void test_finally(void function(), ref bool);

import std.stdio;

void test1() {
    bool caught;
    bool finalized;
    bool notthrown;
    try {
        throwObjc();
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
        test_throw();
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
    bool caught = test_catch(&throwObjc);
    assert(caught);
}

void test4() {
    bool caught;
    bool objcfinalized;
    bool finalized;
    bool notthrown;
    try {
        try
            test_finally(&throwObjc, objcfinalized);
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

void mix1() {
    bool caughtObjc;
    bool caughtD;
    bool finalized;
    bool notthrown;
    try {
        throwD();
        notthrown = true;
    } catch (Exception e) {
        caughtD = true;
    } catch (NSException e) {
        caughtObjc = true;
    } finally {
        finalized = true;
    }
    
    assert(notthrown == false);
    assert(caughtObjc == false);
    assert(caughtD == true);
    assert(finalized == true);
}

void mix2() {
    bool caughtObjc;
    bool caughtD;
    bool finalized;
    bool notthrown;
    try {
        test_throw();
        notthrown = true;
    } catch (Throwable e) {
        caughtD = true;
    } catch (NSException e) {
        caughtObjc = true;
    } finally {
        finalized = true;
    }
    
    assert(notthrown == false);
    assert(caughtD == false);
    assert(caughtObjc == true);
    assert(finalized == true);
}

void mix3() {
    bool caught = test_catch(&throwD);
    assert(caught);
}

void mix4() {
    bool caughtD;
    bool caughtObjc;
    bool objcfinalized;
    bool finalized;
    bool notthrown;
    try {
        try
            test_finally(&throwD, objcfinalized);
        finally
            finalized = true;
        notthrown = true;
    } catch (Throwable e) {
        caughtD = true;
    } catch (NSException e) {
        caughtObjc = true;
    }
    
    assert(notthrown == false);
    assert(objcfinalized == true);
    assert(caughtD == true);
    assert(caughtObjc == false);
    assert(finalized == true);
}

void main() {
    version (X86) {
        test1();
        test2();
        test3();
        test4();

        mix1();
        mix2();
        mix3();
        mix4();
    }
}
