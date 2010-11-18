
extern (Objective-C)
interface ObjcObject {
    bool isEqualToString(ObjcObject other) [isEqualToString:];
}

void main() {
    ObjcObject a = "hello";
    ObjcObject b = "hello";
    ObjcObject c = "hêllo";
//    auto b = cast(ObjcObject)"hello";
    assert(a.isEqualToString(b));
    assert(!a.isEqualToString(c));
}