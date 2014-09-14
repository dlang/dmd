// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
pragma (objc_takestringliteral)
interface ObjcObject {
    static ObjcObject alloc() [alloc];
}

extern (Objective-C)
class NSObject : ObjcObject {
    void* isa;
    this() [init];
    bool isKindOfClass(Class c) [isKindOfClass:];
}

void main() {
    NSObject o = new NSObject;
    NSObject.Class d = NSObject.class;
    ObjcObject.Class c = o.class;
    
    assert(o.class is d);
    assert(o.isKindOfClass(o.class));
    assert(o.isKindOfClass(d));
}