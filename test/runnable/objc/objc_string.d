// PLATFORM: osx
// REQUIRED_ARGS: -L-framework -LCocoa

pragma (objc_takestringliteral)
extern (Objective-C)
interface ObjcObject {
    bool isEqualToString(ObjcObject other) [isEqualToString:];
    wchar characterAtIndex(size_t index) [characterAtIndex:];
    size_t length() @property [length];
}

void main() {
    ObjcObject a = "hello";
    auto b = cast(ObjcObject)"hello";
    ObjcObject c = "allô";
    assert(a.isEqualToString(b));
    assert(!a.isEqualToString(c));
    
    assert(c.length == 4);
    assert(c.characterAtIndex(3) == 'ô');
}