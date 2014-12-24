// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
pragma(mangle, "NSObject")
interface ObjcObject {
    static ObjcObject alloc() @selector("alloc");
    bool conformsToProtocol(Protocol p) @selector("conformsToProtocol:");
}

extern (Objective-C)
class NSObject : ObjcObject {
    void* isa;
    this() @selector("init");
    static bool classConformsToProtocol(Protocol p) @selector("conformsToProtocol:");
}

extern (Objective-C)
pragma(mangle, "Object")
abstract class __Object {
    @disable this();
    void* isa;
}

extern (Objective-C)
abstract class Protocol : __Object {
    @disable this();
}

void main() {
    assert(NSObject.classConformsToProtocol(ObjcObject.protocolof));

    NSObject o = new NSObject;
    assert(o.conformsToProtocol(ObjcObject.protocolof));
}