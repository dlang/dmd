// EXTRA_OBJC_SOURCES: objc_instance_variable.m
// REQUIRED_ARGS: -L-framework -LFoundation

import core.attribute : selector;

extern (Objective-C) extern class NSObject {}

// Defined in `runnable/extra-files/objc_instance_variable.m`
extern (Objective-C)
extern class Foo : NSObject
{
    // int a = 1;
    // int b = 2;
    // int c = 3;

    // Intentionally not declared the above instance variables here to simulate
    // that the base class has changed.
}

extern (Objective-C)
class Bar : Foo
{
    int d;

    static Bar alloc() @selector("alloc");
    Bar init() @selector("init");
    void release() @selector("release");

    void bar() @selector("bar") {}
}

extern (Objective-C) extern class NSString {}

// This is implemented in `runnable/extra-files/objc_instance_variable.m` and
// returns the value of instance variable `c`.
extern (C) int getInstanceVariableC(Foo);

// This is implemented in `runnable/extra-files/objc_instance_variable.m` and
// sets the a value for the instance variables `a`, `b` and `c`.
extern (C) int setInstanceVariables(Foo);

import core.stdc.stdio;

void main()
{
    auto bar = Bar.alloc.init;
    scope (exit) bar.release();

    setInstanceVariables(bar);
    bar.d = 4;

    // if non-fragile instance variables didn't work this would be `4`.
    assert(getInstanceVariableC(bar) == 3);

    // static/dynamic casting
    Foo foo = bar;
    auto bar2 = cast(Bar) foo;
    assert(bar is bar2);

    NSObject nsobj = foo;
    auto foo2 = cast(Foo) nsobj;
    assert(foo is foo2);

    // for dmd, casting within Objective-C is a reinterpret cast
    version(DigitalMars)
        assert(cast(NSString) bar !is null);

    // casting from/to other linkage is always null
    static extern(C++) class Cpp {}
    assert(cast(Object) bar is null);
    assert(cast(Cpp) bar is null);

    auto obj = new Object;
    assert(cast(Bar) obj is null);
}
