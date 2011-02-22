// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
    static NSObject alloc();
    static NSObject allocWithZone(void*);
    NSObject init();
}

void main() {
    extern (Objective-C)
    NSObject __selector() allocSel = &NSObject.alloc;
    NSObject obj = allocSel(NSObject.class);
    assert(obj);
    
    extern (Objective-C)
    NSObject __selector() initSel = &NSObject.init;
    obj = initSel(obj);
    assert(obj);
    
    // Test with one argument
    extern (Objective-C)
    NSObject __selector(void*) allocWithZoneSel = &NSObject.allocWithZone;
    NSObject objZ = allocWithZoneSel(NSObject.class, null);
    assert(objZ);
    
    extern (Objective-C)
    NSObject __selector() nullSel = null;
    assert(nullSel == null);
}