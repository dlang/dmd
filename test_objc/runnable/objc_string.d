
extern (Objective-C)
interface ObjcObject {
    bool isEqualToString(ObjcObject other) [isEqualToString:];
}

void main() {
    ObjcObject a = "hello";
    ObjcObject b = "hello";
//    auto b = cast(ObjcObject)"hello";
    assert(a.isEqualToString(b));
}