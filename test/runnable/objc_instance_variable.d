// EXTRA_OBJC_SOURCES: objc_instance_variable.m
// REQUIRED_ARGS: -L-framework -LFoundation

extern (Objective-C) class NSObject {}

// Defined in `runnable/extra-files/objc_instance_variable.m`
extern (Objective-C)
class Foo : NSObject
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

// This is implemented in `runnable/extra-files/objc_instance_variable.m` and
// returns the value of instance variable `c`.
extern (C) int getInstanceVariableC(Foo);

// This is implemented in `runnable/extra-files/objc_instance_variable.m` and
// sets the a value for the instance variables `a`, `b` and `c`.
extern (C) int setInstanceVariables(Foo);

import std.stdio;

void main()
{
    auto bar = Bar.alloc.init;
    scope (exit) bar.release();

    setInstanceVariables(bar);
    bar.d = 4;

    // if non-fragile instance variables didn't work this would be `4`.
    assert(getInstanceVariableC(bar) == 3);
}

