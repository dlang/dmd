// EXTRA_OBJC_SOURCES: objc_class.m
// REQUIRED_ARGS: -L-framework -LFoundation

// This function is implemented in `runnable/extra-files/objc_class.m` and will
// create a new instance of `Foo` (defined below), call `callFooInstanceMethod`
// and return the result of `callFooInstanceMethod`.
extern (C) int callFooInstanceMethod(int);

// This function is implemented in `runnable/extra-files/objc_class.m` and will
// call the `classMethod` method defined in `Foo` (below) and return the result
// of `classMethod`
extern (C) int callFooClassMethod(int);

extern (Objective-C)
extern class NSObject
{
    static NSObject alloc() @selector("alloc");
    NSObject init() @selector("init");
    void release() @selector("release");
}

extern (Objective-C)
class Foo : NSObject
{
    override static Foo alloc() @selector("alloc");
    override Foo init() @selector("init");

    static int classMethod(int a) @selector("classMethod:")
    {
        return a;
    }

    int instanceMethod(int a) @selector("instanceMethod:")
    {
        return a;
    }
}

void testClassDeclaration()
{
    assert(NSObject.alloc.init !is null);
}

void testSubclass()
{
    assert(Foo.alloc.init.instanceMethod(3) == 3);
}

// verify that Objective-C can instantiate a class defined in D and call a
// both a instance method and a class/static method.
void testCallThroughObjc()
{
    assert(callFooInstanceMethod(4) == 4);
    assert(callFooClassMethod(5) == 5);
}

void main()
{
    testClassDeclaration();
    testSubclass();
    testCallThroughObjc();
}
