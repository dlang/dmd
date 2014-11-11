// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

extern (Objective-C)
class NSObject {
    static NSObject alloc() @selector("alloc");
    static NSObject allocWithZone(void*) @selector("allocWithZone:");
    NSObject init() @selector("init");
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
    
    // Test with with auto
    auto allocWithZoneSelAuto = &NSObject.allocWithZone;
    NSObject objA = allocWithZoneSelAuto(NSObject.class, null);
    assert(objA);
    
    NSObject __selector() nullSel = null;
    assert(nullSel == null);
    
    NSObject __selector() stringSel = cast(NSObject __selector())"hello";
    assert(cast(SEL)stringSel == sel_registerName("hello"));
    
    SEL untypedSel = cast(SEL)"hello";
    assert(untypedSel == sel_registerName("hello"));
}