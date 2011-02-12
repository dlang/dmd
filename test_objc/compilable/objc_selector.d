
extern (Objective-C)
class NSObject {
    static NSObject alloc();
    NSObject init();
}

void main() {
    extern (Objective-C)
    NSObject __selector() allocSel = &NSObject.alloc;
    //NSObject obj = allocSel(NSObject.class);
    //assert(obj);
    
    extern (Objective-C)
    NSObject __selector() initSel = &NSObject.init;
    //obj = initSel(obj);
    //assert(obj);
    
    extern (Objective-C)
    NSObject __selector() nullSel = null;
}