// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
pragma (objc_takestringliteral)
interface ObjcObject {
    static ObjcObject alloc() @selector("alloc");
}

extern (Objective-C)
class NSObject : ObjcObject {
    void* isa;
    this() @selector("init");
    bool isKindOfClass(Class c) @selector("isKindOfClass:");
}

void main() {
    NSObject o = new NSObject;
    NSObject.Class d = NSObject.class;
    ObjcObject.Class c = o.class;
    
    assert(o.class is d);
    assert(o.isKindOfClass(o.class));
    assert(o.isKindOfClass(d));
}