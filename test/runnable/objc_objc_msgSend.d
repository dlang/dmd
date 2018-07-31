// EXTRA_OBJC_SOURCES: objc_objc_msgSend.m
// REQUIRED_ARGS: -L-framework -LFoundation

extern (C) Class objc_lookUpClass(in char* name);

struct Struct
{
    int a, b, c, d, e;
}

extern (Objective-C)
interface Class
{
    stret alloc_stret() @selector("alloc");
    fp2ret alloc_fp2ret() @selector("alloc");
    fpret alloc_fpret() @selector("alloc");
    float32 alloc_float32() @selector("alloc");
    double64 alloc_double64() @selector("alloc");
}

extern (Objective-C)
interface stret
{
    stret init() @selector("init");
    Struct getValue() @selector("getValue");
    void release() @selector("release");
}

extern (Objective-C)
interface fp2ret
{
    fp2ret init() @selector("init");
    creal getValue() @selector("getValue");
    void release() @selector("release");
}

extern (Objective-C)
interface fpret
{
    fpret init() @selector("init");
    real getValue() @selector("getValue");
    void release() @selector("release");
}

extern (Objective-C)
interface float32
{
    float32 init() @selector("init");
    float getValue() @selector("getValue");
    void release() @selector("release");
}

extern (Objective-C)
interface double64
{
    double64 init() @selector("init");
    double getValue() @selector("getValue");
    void release() @selector("release");
}

void test_stret()
{
    auto c = objc_lookUpClass("stret");
    auto o = c.alloc_stret().init();
    assert(o.getValue() == Struct(3, 3, 3, 3, 3));
    o.release();
}

void test_fp2ret()
{
    auto c = objc_lookUpClass("fp2ret");
    auto o = c.alloc_fp2ret().init();
    assert(o.getValue() == 1+3i);
    o.release();
}

void test_fpret()
{
    auto c = objc_lookUpClass("fpret");
    auto o = c.alloc_fpret().init();
    assert(o.getValue() == 0.000000000000000002L);
    o.release();
}

void test_float32()
{
    auto c = objc_lookUpClass("float32");
    auto o = c.alloc_float32.init();
    assert(o.getValue == 0.2f);
    o.release();
}

void test_double64()
{
    auto c = objc_lookUpClass("double64");
    auto o = c.alloc_double64.init();
    assert(o.getValue == 0.2);
    o.release();
}

void main()
{
    // test_stret();
    // test_fp2ret();
    test_fpret();
    test_float32();
    test_double64();
}
