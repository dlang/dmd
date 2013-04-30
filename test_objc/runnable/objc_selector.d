// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
    static NSObject alloc() [alloc];
    static NSObject allocWithZone(void*) [allocWithZone:];
    NSObject init() [init];
}

import objc.runtime;

void main() {
    extern (Objective-C) NSObject __selector() allocSel = &NSObject.alloc;
    NSObject obj = allocSel(NSObject.class);
    assert(obj);
    
    NSObject __selector() initSel = &NSObject.init;
    obj = initSel(obj);
    assert(obj);
    
    // Test with one argument
    NSObject __selector(void*) allocWithZoneSel = &NSObject.allocWithZone;
    NSObject objZ = allocWithZoneSel(NSObject.class, null);
    assert(objZ);
    
    NSObject __selector() nullSel = null;
    assert(nullSel == null);
    
    NSObject __selector() stringSel = cast(NSObject __selector())"hello";
    assert(cast(SEL)stringSel == sel_registerName("hello"));
    
    SEL untypedSel = cast(SEL)"hello";
    assert(untypedSel == sel_registerName("hello"));
}