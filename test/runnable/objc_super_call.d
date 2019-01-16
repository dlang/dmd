// EXTRA_OBJC_SOURCES: objc_super_call.m
// REQUIRED_ARGS: -L-framework -LFoundation

extern (Objective-C)
class NSObject
{
    void release() @selector("release");
}

// Defined in `runnable/extra-files/objc_super_call.m`
extern (Objective-C)
class Foo : NSObject
{
    // returns 3
    int foo() @selector("foo");
}

extern (Objective-C)
class Bar : Foo
{
    static Bar alloc() @selector("alloc");
    Bar init() @selector("init");

    override int foo() @selector("foo")
    {
        return super.foo() + 1;
    }
}

void main()
{
    auto bar = Bar.alloc.init;
    scope (exit) bar.release();

    assert(bar.foo == 4);
}
