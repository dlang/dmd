// EXTRA_OBJC_SOURCES
// REQUIRED_ARGS: -L-framework -LFoundation

extern (Objective-C)
interface NSObject
{
    static NSObject alloc() @selector("alloc");
    static NSObject allocWithZone(void* zone) @selector("allocWithZone:");

    NSObject init() @selector("init");
}

void main()
{
    auto obj1 = NSObject.alloc();
    auto obj2 = NSObject.allocWithZone(null);
    auto obj3 = NSObject.alloc().init();

    assert(obj1);
    assert(obj2);
    assert(obj3);
}
