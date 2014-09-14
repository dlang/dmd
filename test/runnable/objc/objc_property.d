// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

import objc.runtime;

extern (Objective-C)
class NSObject {
    static NSObject alloc() [alloc];
    this() [init];
}

class TestObject : NSObject {

    @property {
        bool prop() { return true; } // getter
        void prop(bool value) {} // setter
    }

}

void main() {
    bool __selector() getterSel = &TestObject.prop;
    void __selector(bool) setterSel = &TestObject.prop;
    assert(cast(SEL)getterSel == sel_registerName("prop"));
    assert(cast(SEL)setterSel == sel_registerName("setProp:"));
}