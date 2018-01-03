module test16096a;

extern (Objective-C)
interface Class
{
    NSObject alloc() @selector("alloc");
}

extern (Objective-C)
interface NSObject
{
    NSObject initWithUTF8String(in char* str) @selector("initWithUTF8String:");
    void release() @selector("release");
}

extern (C) Class objc_lookUpClass(in char* name);

void test()
{
    auto c = objc_lookUpClass("NSString");
    auto o = c.alloc().initWithUTF8String("hello");
    o.release();
}
