// EXTRA_OBJC_SOURCES:
// REQUIRED_ARGS: -L-framework -LFoundation

extern(Objective-C)
extern class NSObject
{
    static NSObject alloc();
    NSObject init();

    @property NSString className() const;
}

extern(Objective-C)
extern class NSString : NSObject
{
    override static NSString alloc();
    override NSString init();

    @property const(char)* UTF8String() const;
}

extern(Objective-C)
class MyClass : NSObject
{
    int x;

    override static MyClass alloc();
    override MyClass init() { x = 42; return this; }

    @property bool isFourtyTwo() => x == 42;
    @property void isFourtyTwo(bool value) { x = value ? 42 : 0; }

    void myFunction(int a, int b, int c)
    {
        x = a + b + c;
    }
}

extern(C) void* object_getClass(NSObject obj);
extern(C) void* class_getInstanceMethod(void* cls, void* sel);
extern(C) void* method_getName(void* m);
extern(C) void* sel_registerName(const(char)* str);
extern(C) bool sel_isEqual(void* lhs, void* rhs);

bool validateMethod(NSObject obj, const(char)* selName)
{
    auto sel = sel_registerName(selName);

    auto cls = object_getClass(obj);
    if (auto mth = class_getInstanceMethod(cls, sel)) {
        return sel_isEqual(sel, method_getName(mth));
    }
    return false;
}

void main()
{
    // Basic alloc & init
    auto obj = NSObject.alloc.init;
    assert(obj !is null);

    // Basic property
    auto cname = obj.className();
    assert(cname !is null);
    assert(cname.UTF8String());

    // Properties
    obj = MyClass.alloc().init();
    assert(obj !is null);
    assert(validateMethod(obj, "isFourtyTwo"));     // Case: isXYZ
    assert(validateMethod(obj, "setFourtyTwo:"));   // Case: isXYZ
    assert(validateMethod(obj, "myFunction:b:c:")); // Case: Auto-gen function selector.
}
