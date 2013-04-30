
extern (Objective-C)
interface ObjcObject {
}

extern (Objective-C)
class NSObject : ObjcObject {
    void* isa;
}

void main() {
    NSObject.Class d = new NSObject.Class;
}