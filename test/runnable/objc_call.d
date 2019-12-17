// EXTRA_OBJC_SOURCES
// REQUIRED_ARGS: -L-framework -LFoundation

extern (Objective-C)
extern class Class
{
    NSObject alloc() @selector("alloc");
}

extern (Objective-C)
extern class NSObject
{
    NSObject initWithUTF8String(in char* str) @selector("initWithUTF8String:");
    void release() @selector("release");
}

extern (C) void NSLog(NSObject, ...);
extern (C) Class objc_lookUpClass(in char* name);

void main()
{
    auto c = objc_lookUpClass("NSString");
    auto o = c.alloc().initWithUTF8String("hello");
    NSLog(o);
    o.release();
}
