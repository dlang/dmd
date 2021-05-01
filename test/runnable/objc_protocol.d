// EXTRA_OBJC_SOURCES: objc_protocol.m
// REQUIRED_ARGS: -L-lobjc

import core.attribute : selector;

// This function is implemented in `runnable/extra-files/objc_protocol.m` and will
// call the `instanceMethod` method declared in `Foo` (below) and return the result
// of `instanceMethod`
extern (C) int callFooInstanceMethod(Foo, int);

// This function is implemented in `runnable/extra-files/objc_protocol.m` and will
// call the `classMethod` method declared in `Foo` (below) and return the result
// of `classMethod`
extern (C) int callFooClassMethod(Foo, int);

extern (Objective-C)
extern class NSObject
{
    static NSObject alloc() @selector("alloc");
    NSObject init() @selector("init");
}

extern (Objective-C)
interface Foo
{
    static int classMethod(int) @selector("classMethod:");
    int instanceMethod(int) @selector("instanceMethod:");
}

extern (Objective-C)
class Bar : NSObject, Foo
{
    override static Bar alloc() @selector("alloc");
    override Bar init() @selector("init");

    static int classMethod(int a) @selector("classMethod:")
    {
        return a;
    }

    int instanceMethod(int a) @selector("instanceMethod:")
    {
        return a;
    }
}

// verify that Objective-C can access a protocol declared in D and call both an
// instance method and a class/static method.
void testCallThroughObjc()
{
    Foo bar = Bar.alloc.init;

    assert(callFooInstanceMethod(bar, 4) == 4);
    assert(callFooClassMethod(bar, 5) == 5);
}

void main()
{
    testCallThroughObjc();
}
