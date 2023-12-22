import core.stdcpp.new_;
import core.stdcpp.xutility : __cpp_aligned_new;

extern(C++) struct MyStruct
{
    int* a;
    double* b;
    MyStruct* c;
}

extern(C++) MyStruct cpp_new();
extern(C++) void cpp_delete(ref MyStruct s);
extern(C++) size_t defaultAlignment();
extern(C++) bool hasAlignedNew();

unittest
{
    // test the magic numbers are consistent between C++ and D
    assert(hasAlignedNew() == !!__cpp_aligned_new, "__cpp_aligned_new does not match C++ compiler");
    static if (__cpp_aligned_new)
        assert(defaultAlignment() == __STDCPP_DEFAULT_NEW_ALIGNMENT__, "__STDCPP_DEFAULT_NEW_ALIGNMENT__ does not match C++ compiler");

    // alloc in C++, delete in D
    MyStruct s = cpp_new();
    __cpp_delete(cast(void*)s.a);
    __cpp_delete(cast(void*)s.b);
    __cpp_delete(cast(void*)s.c);

    // alloc in D, delete in C++
    s.a = cast(int*)__cpp_new(int.sizeof);
    s.b = cast(double*)__cpp_new(double.sizeof);
    s.c = cast(MyStruct*)__cpp_new(MyStruct.sizeof);
    cpp_delete(s);
}

@nogc unittest
{
    // Test cpp_new and cpp_delete for a struct infer @nogc.
    import core.stdcpp.new_: cpp_new, cpp_delete;
    extern(C++) static struct MyStructNoGC
    {
        __gshared int numDeleted;
        int x = 3;
        this(int x) @nogc { this.x = x; }
        ~this() @nogc { ++numDeleted; }
    }

    MyStructNoGC* c1 = cpp_new!MyStructNoGC(4);
    assert(c1.x == 4);
    assert(MyStructNoGC.numDeleted == 0);
    cpp_delete(c1);
    assert(MyStructNoGC.numDeleted == 1);
}

/+
// BUG: @nogc not being applied to __xdtor for extern(C++) class.
extern(C++) class MyClassNoGC
{
    __gshared int numDeleted;
    int x = 3;
    this(int x) @nogc { this.x = x; }
    ~this() @nogc { ++numDeleted; }
}

@nogc unittest
{
    // Test cpp_new and cpp_delete for a class infer @nogc.
    import core.stdcpp.new_: cpp_new, cpp_delete;

    MyClassNoGC c1 = cpp_new!MyClassNoGC(4);
    assert(c1.x == 4);
    assert(MyClassNoGC.numDeleted == 0);
    cpp_delete(c1);
    assert(MyClassNoGC.numDeleted == 1);
}
+/

unittest
{
    import core.stdcpp.new_: cpp_new, cpp_delete;

    // Test cpp_new & cpp_delete are callable with a struct whose destructor
    // is not @nogc.
    {
        extern(C++) static struct MyStructGC
        {
            __gshared int numDeleted;
            int x = 5;
            this(int x)
            {
                if (x == int.min)
                    throw new Exception("forbidden number");
                this.x = x;
            }
            ~this()
            {
                if (++numDeleted < 0)
                    throw new Exception("overflow in dtor");
            }
        }
        static assert(!is(typeof(() @nogc => cpp_new!MyStructGC(6))));
        MyStructGC* c2 = cpp_new!MyStructGC(6);
        assert(c2.x == 6);
        static assert(!is(typeof(() @nogc => cpp_delete(c2))));
        assert(MyStructGC.numDeleted == 0);
        cpp_delete(c2);
        assert(MyStructGC.numDeleted == 1);
    }

    // Test cpp_new & cpp_delete are callable with a class whose destructor
    // is not @nogc.
    {
        extern(C++) static class MyClassGC
        {
            __gshared int numDeleted;
            int x = 5;
            this(int x)
            {
                if (x == int.min)
                    throw new Exception("forbidden number x");
                this.x = x;
            }
            ~this()
            {
                if (++numDeleted < 0)
                    throw new Exception("overflow in dtor for x");
            }
        }
        static assert(!is(typeof(() @nogc => cpp_new!MyClassGC(6))));
        MyClassGC c2 = cpp_new!MyClassGC(6);
        assert(c2.x == 6);
        static assert(!is(typeof(() @nogc => cpp_delete(c2))));
        assert(MyClassGC.numDeleted == 0);
        cpp_delete(c2);
        assert(MyClassGC.numDeleted == 1);
    }
}

unittest
{
    import core.stdcpp.new_: cpp_new, cpp_delete;

    {
        extern(C++) static struct S
        {
            __gshared int numDeleted;
            __gshared int lastDeleted;
            int i;
            ~this()
            {
                lastDeleted = i;
                numDeleted++;
            }
        }
        S *s = cpp_new!S(12345);
        cpp_delete(s);
        assert(S.numDeleted == 1);
        assert(S.lastDeleted == 12345);
        s = null;
        cpp_delete(s);
        assert(S.numDeleted == 1);
        assert(S.lastDeleted == 12345);
    }

    {
        extern(C++) static class C
        {
            __gshared int numDeleted;
            __gshared int lastDeleted;
            int i;
            this(int i)
            {
                this.i = i;
            }
            ~this()
            {
                lastDeleted = i;
                numDeleted++;
            }
        }
        C c = cpp_new!C(54321);
        cpp_delete(c);
        assert(C.numDeleted == 1);
        assert(C.lastDeleted == 54321);
        c = null;
        cpp_delete(c);
        assert(C.numDeleted == 1);
        assert(C.lastDeleted == 54321);
    }
}
