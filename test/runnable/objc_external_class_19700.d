// EXTRA_OBJC_SOURCES: objc_instance_variable.m
// REQUIRED_ARGS: -L-framework -LFoundation

// Verify that a class with a method with D linkage is considered an externally
// defined class. https://issues.dlang.org/show_bug.cgi?id=19700

extern (Objective-C) extern class NSObject {}

extern (Objective-C)
extern class NSString : NSObject
{
    NSString init() @selector("init");
    static NSString alloc() @selector("alloc");

    const(char)* UTF8String() @selector("UTF8String");

    NSString initWithBytes(
        const(void)* bytes,
        size_t length,
        size_t encoding
    ) @selector("initWithBytes:length:encoding:");

    extern (D) NSString init(string s)
    {
        return initWithBytes(s.ptr, s.length, NSUTF8StringEncoding);
    }

    // adding C and C++ linkages for completeness
    extern (C) void foo() {}
    extern (C++) void bar() {}
}

enum NSUTF8StringEncoding = 4;

void main()
{
    auto s = "hello";
    auto str = NSString.alloc.initWithBytes(s.ptr, s.length, NSUTF8StringEncoding);

    assert(str !is null);
}
