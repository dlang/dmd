// Basic opImplicitCast to enum (enum type inference)
enum MyEnum { A, B, C }

struct Symbol(string name)
{
    T opImplicitCast(T)()
    {
        return __traits(getMember, T, name);
    }

    bool opEquals(T)(T t) const
    {
        return t == __traits(getMember, T, name);
    }
}

struct _
{
    static ref enum opDispatch(string name) = Symbol!name.init;
}

void test1()
{
    MyEnum something = _.B;
    assert(something == MyEnum.B);

    something = _.A;
    assert(something == MyEnum.A);
}

// opImplicitCast with switch case
void test2()
{
    MyEnum e = MyEnum.B;
    int result;

    switch (e)
    {
        case _.A: result = 1; break;
        case _.B: result = 2; break;
        case _.C: result = 3; break;
        default: result = 0;
    }

    assert(result == 2);
}

// opImplicitCast to basic types
struct IntWrapper
{
    int value;

    this(int v) { value = v; }

    T opImplicitCast(T)() const if (__traits(isSame, T, int))
    {
        return value;
    }
}

void test3()
{
    IntWrapper iw = IntWrapper(42);
    int x = iw;
    assert(x == 42);
}

// opImplicitCast in function arguments
void takeInt(int x)
{
    assert(x == 100);
}

void takeEnum(MyEnum e)
{
    assert(e == MyEnum.C);
}

void test4()
{
    IntWrapper iw = IntWrapper(100);
    takeInt(iw);

    takeEnum(_.C);
}

// opImplicitCast with multiple target types
struct MultiCast
{
    int value;

    this(int v) { value = v; }

    T opImplicitCast(T)() const
    {
        static if (__traits(isSame, T, int))
            return value;
        else static if (__traits(isSame, T, long))
            return cast(long)value;
        else static if (__traits(isSame, T, double))
            return cast(double)value;
        else
            static assert(false, "Unsupported type");
    }
}

void test5()
{
    MultiCast mc = MultiCast(50);
    int i = mc;
    long l = mc;
    double d = mc;

    assert(i == 50);
    assert(l == 50L);
    assert(d == 50.0);
}

// opImplicitCast in struct with const
struct ConstCast
{
    int value;

    this(int v) { value = v; }

    T opImplicitCast(T)() const if (__traits(isSame, T, int))
    {
        return value;
    }
}

void test6()
{
    const ConstCast cc = ConstCast(200);
    int x = cc;
    assert(x == 200);
}

// Nested struct with opImplicitCast
struct InnerWrapper
{
    int value;

    T opImplicitCast(T)() if (__traits(isSame, T, int))
    {
        return value;
    }
}

struct OuterWrapper
{
    InnerWrapper inner;

    T opImplicitCast(T)() if (__traits(isSame, T, int))
    {
        return inner.opImplicitCast!T();
    }
}

void test7()
{
    OuterWrapper ow;
    ow.inner.value = 300;
    int x = ow;
    assert(x == 300);
}

// opImplicitCast with class types
class MyClass
{
    int value;
    this(int v) { value = v; }
}

struct ClassWrapper
{
    MyClass obj;

    this(int v) { obj = new MyClass(v); }

    T opImplicitCast(T)() if (is(T == MyClass))
    {
        return obj;
    }
}

void test8()
{
    ClassWrapper cw = ClassWrapper(500);
    MyClass c = cw;
    assert(c.value == 500);
}

// opImplicitCast with template constraints
struct ConstrainedCast
{
    long value;

    this(long v) { value = v; }

    T opImplicitCast(T)() if (is(T : long))
    {
        return cast(T)value;
    }
}

void test9()
{
    ConstrainedCast cc = ConstrainedCast(1000);
    int i = cc;
    long l = cc;

    assert(i == 1000);
    assert(l == 1000);
}

// opImplicitCast in array indexing context
struct IndexWrapper
{
    size_t idx;

    this(size_t i) { idx = i; }

    T opImplicitCast(T)() if (__traits(isSame, T, size_t))
    {
        return idx;
    }
}

void test10()
{
    int[5] arr = [10, 20, 30, 40, 50];
    IndexWrapper iw = IndexWrapper(2);
    size_t idx = iw;
    assert(arr[idx] == 30);
}


void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
}
