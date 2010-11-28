
extern (Objective-C)
pragma(objc_nameoverride, "NSObject")
interface ObjcObject {
    static ObjcObject alloc();
    bool conformsToProtocol(Protocol p) [conformsToProtocol:];
}

extern (Objective-C)
class NSObject : ObjcObject {
    void* isa;
    this() [init];
    static bool classConformsToProtocol(Protocol p) [conformsToProtocol:];
}

extern (Objective-C)
pragma(objc_nameoverride, "Object")
abstract class __Object {
    @disable this();
    void* isa;
}

extern (Objective-C)
abstract class Protocol : __Object {
    @disable this();
}

void main() {
    assert(NSObject.classConformsToProtocol(ObjcObject.interface));

    NSObject o = new NSObject;
    assert(o.conformsToProtocol(ObjcObject.interface));
}