
extern (C) int printf(const(char*) fmt, ...);

struct Tup(T...)
{
    T field;
    alias field this;

    bool opEquals(const Tup rhs) const
    {
        foreach (i, _; T)
            if (field[i] != rhs.field[i])
                return false;
        return true;
    }
}

Tup!T tup(T...)(T fields)
{
    return typeof(return)(fields);
}

template Seq(T...)
{
    alias T Seq;
}

/**********************************************/

struct S
{
    int x;
    alias x this;
}

int foo(int i)
{
    return i * 2;
}

void test1()
{
    S s;
    s.x = 7;
    int i = -s;
    assert(i == -7);

    i = s + 8;
    assert(i == 15);

    i = s + s;
    assert(i == 14);

    i = 9 + s;
    assert(i == 16);

    i = foo(s);
    assert(i == 14);
}

/**********************************************/

class C
{
    int x;
    alias x this;
}

void test2()
{
    C s = new C();
    s.x = 7;
    int i = -s;
    assert(i == -7);

    i = s + 8;
    assert(i == 15);

    i = s + s;
    assert(i == 14);

    i = 9 + s;
    assert(i == 16);

    i = foo(s);
    assert(i == 14);
}

/**********************************************/

void test3()
{
    Tup!(int, double) t;
    t[0] = 1;
    t[1] = 1.1;
    assert(t[0] == 1);
    assert(t[1] == 1.1);
    printf("%d %g\n", t[0], t[1]);
}

/**********************************************/

struct Iter
{
    bool empty() { return true; }
    void popFront() { }
    ref Tup!(int, int) front() { return *new Tup!(int, int); }
    ref Iter opSlice() { return this; }
}

void test4()
{
    foreach (a; Iter()) { }
}

/**********************************************/

void test5()
{
    static struct Double1 {
        double val = 1;
        alias val this;
    }
    static Double1 x() { return Double1(); }
    x()++;
}

/**********************************************/
// 4773

void test4773()
{
    struct Rebindable
    {
        Object obj;
        @property const(Object) get(){ return obj; }
        alias get this;
    }

    Rebindable r;
    if (r) assert(0);
    r.obj = new Object;
    if (!r) assert(0);
}

/**********************************************/
// 5188

void test5188()
{
    struct S
    {
        int v = 10;
        alias v this;
    }

    S s;
    assert(s <= 20);
    assert(s != 14);
}

/***********************************************/

struct Foo {
  void opIndexAssign(int x, size_t i) {
    val = x;
  }
  void opSliceAssign(int x, size_t a, size_t b) {
    val = x;
  }
  int val;
}

struct Bar {
   Foo foo;
   alias foo this;
}

void test6() {
   Bar b;
   b[0] = 1;
   assert(b.val == 1);
   b[0 .. 1] = 2;
   assert(b.val == 2);
}

/**********************************************/
// 2781

struct Tuple2781a(T...) {
    T data;
    alias data this;
}

struct Tuple2781b(T) {
    T data;
    alias data this;
}

void test2781()
{
    Tuple2781a!(uint, float) foo;
    foreach(elem; foo) {}

    {
        Tuple2781b!(int[]) bar1;
        foreach(elem; bar1) {}

        Tuple2781b!(int[int]) bar2;
        foreach(key, elem; bar2) {}

        Tuple2781b!(string) bar3;
        foreach(dchar elem; bar3) {}
    }

    {
        Tuple2781b!(int[]) bar1;
        foreach(elem; bar1) goto L1;

        Tuple2781b!(int[int]) bar2;
        foreach(key, elem; bar2) goto L1;

        Tuple2781b!(string) bar3;
        foreach(dchar elem; bar3) goto L1;
    L1:
        ;
    }


    int eval;

    auto t1 = tup(10, "str");
    auto i1 = 0;
    foreach (e; t1)
    {
        pragma(msg, "[] = ", typeof(e));
        static if (is(typeof(e) == int   )) assert(i1 == 0 && e == 10);
        static if (is(typeof(e) == string)) assert(i1 == 1 && e == "str");
        ++i1;
    }

    auto t2 = tup(10, "str");
    foreach (i2, e; t2)
    {
        pragma(msg, "[", cast(int)i2, "] = ", typeof(e));
        static if (is(typeof(e) == int   )) { static assert(i2 == 0); assert(e == 10); }
        static if (is(typeof(e) == string)) { static assert(i2 == 1); assert(e == "str"); }
    }

    auto t3 = tup(10, "str");
    auto i3 = 2;
    foreach_reverse (e; t3)
    {
        --i3;
        pragma(msg, "[] = ", typeof(e));
        static if (is(typeof(e) == int   )) assert(i3 == 0 && e == 10);
        static if (is(typeof(e) == string)) assert(i3 == 1 && e == "str");
    }

    auto t4 = tup(10, "str");
    foreach_reverse (i4, e; t4)
    {
        pragma(msg, "[", cast(int)i4, "] = ", typeof(e));
        static if (is(typeof(e) == int   )) { static assert(i4 == 0); assert(e == 10); }
        static if (is(typeof(e) == string)) { static assert(i4 == 1); assert(e == "str"); }
    }

    eval = 0;
    foreach (i, e; tup(tup((eval++, 10), 3.14), tup("str", [1,2])))
    {
        static if (i == 0) assert(e == tup(10, 3.14));
        static if (i == 1) assert(e == tup("str", [1,2]));
    }
    assert(eval == 1);

    eval = 0;
    foreach (i, e; tup((eval++,10), tup(3.14, tup("str", tup([1,2])))))
    {
        static if (i == 0) assert(e == 10);
        static if (i == 1) assert(e == tup(3.14, tup("str", tup([1,2]))));
    }
    assert(eval == 1);
}

/**********************************************/
// 6546

void test6546()
{
    class C {}
    class D : C {}

    struct S { C c; alias c this; } // S : C
    struct T { S s; alias s this; } // T : S
    struct U { T t; alias t this; } // U : T

    C c;
    D d;
    S s;
    T t;
    U u;

    assert(c is c);  // OK
    assert(c is d);  // OK
    assert(c is s);  // OK
    assert(c is t);  // OK
    assert(c is u);  // OK

    assert(d is c);  // OK
    assert(d is d);  // OK
    assert(d is s);  // doesn't work
    assert(d is t);  // doesn't work
    assert(d is u);  // doesn't work

    assert(s is c);  // OK
    assert(s is d);  // doesn't work
    assert(s is s);  // OK
    assert(s is t);  // doesn't work
    assert(s is u);  // doesn't work

    assert(t is c);  // OK
    assert(t is d);  // doesn't work
    assert(t is s);  // doesn't work
    assert(t is t);  // OK
    assert(t is u);  // doesn't work

    assert(u is c);  // OK
    assert(u is d);  // doesn't work
    assert(u is s);  // doesn't work
    assert(u is t);  // doesn't work
    assert(u is u);  // OK
}

/**********************************************/
// 6736

void test6736()
{
    static struct S1
    {
        struct S2 // must be 8 bytes in size
        {
            uint a, b;
        }
        S2 s2;
        alias s2 this;
    }
    S1 c;
    static assert(!is(typeof(c + c)));
}

/**********************************************/
// 2777

struct ArrayWrapper(T) {
    T[] array;
    alias array this;
}

// alias array this
void test2777a()
{
    ArrayWrapper!(uint) foo;
    foo.length = 5;  // Works
    foo[0] = 1;      // Works
    auto e0 = foo[0];  // Works
    auto e4 = foo[$ - 1];  // Error:  undefined identifier __dollar
    auto s01 = foo[0..2];  // Error:  ArrayWrapper!(uint) cannot be sliced with[]
}

// alias tuple this
void test2777b()
{
    auto t = tup(10, 3.14, "str", [1,2]);

    assert(t[$ - 1] == [1,2]);

    auto f1 = t[];
    assert(f1[0] == 10);
    assert(f1[1] == 3.14);
    assert(f1[2] == "str");
    assert(f1[3] == [1,2]);

    auto f2 = t[1..3];
    assert(f2[0] == 3.14);
    assert(f2[1] == "str");
}

/****************************************/
// 2787

struct Base2787
{
    int x;
    void foo() { auto _ = x; }
}

struct Derived2787
{
    Base2787 _base;
    alias _base this;
    int y;
    void bar() { auto _ = x; }
}

/***********************************/
// 6508

void test6508()
{
    int x, y;
    Seq!(x, y) = tup(10, 20);
    assert(x == 10);
    assert(y == 20);
}

/***********************************/
// 6369

void test6369a()
{
    alias Seq!(int, string) Field;

    auto t1 = Tup!(int, string)(10, "str");
    Field field1 = t1;           // NG -> OK
    assert(field1[0] == 10);
    assert(field1[1] == "str");

    auto t2 = Tup!(int, string)(10, "str");
    Field field2 = t2.field;     // NG -> OK
    assert(field2[0] == 10);
    assert(field2[1] == "str");

    auto t3 = Tup!(int, string)(10, "str");
    Field field3;
    field3 = t3.field;
    assert(field3[0] == 10);
    assert(field3[1] == "str");
}

void test6369b()
{
    auto t = Tup!(Tup!(int, double), string)(tup(10, 3.14), "str");

    Seq!(int, double, string) fs1 = t;
    assert(fs1[0] == 10);
    assert(fs1[1] == 3.14);
    assert(fs1[2] == "str");

    Seq!(Tup!(int, double), string) fs2 = t;
    assert(fs2[0][0] == 10);
    assert(fs2[0][1] == 3.14);
    assert(fs2[0] == tup(10, 3.14));
    assert(fs2[1] == "str");

    Tup!(Tup!(int, double), string) fs3 = t;
    assert(fs3[0][0] == 10);
    assert(fs3[0][1] == 3.14);
    assert(fs3[0] == tup(10, 3.14));
    assert(fs3[1] == "str");
}

void test6369c()
{
    auto t = Tup!(Tup!(int, double), Tup!(string, int[]))(tup(10, 3.14), tup("str", [1,2]));

    Seq!(int, double, string, int[]) fs1 = t;
    assert(fs1[0] == 10);
    assert(fs1[1] == 3.14);
    assert(fs1[2] == "str");
    assert(fs1[3] == [1,2]);

    Seq!(int, double, Tup!(string, int[])) fs2 = t;
    assert(fs2[0] == 10);
    assert(fs2[1] == 3.14);
    assert(fs2[2] == tup("str", [1,2]));

    Seq!(Tup!(int, double), string, int[]) fs3 = t;
    assert(fs3[0] == tup(10, 3.14));
    assert(fs3[0][0] == 10);
    assert(fs3[0][1] == 3.14);
    assert(fs3[1] == "str");
    assert(fs3[2] == [1,2]);
}

void test6369d()
{
    int eval = 0;
    Seq!(int, string) t = tup((++eval, 10), "str");
    assert(eval == 1);
    assert(t[0] == 10);
    assert(t[1] == "str");
}

/**********************************************/
// 6434

struct Variant6434{}

struct A6434
{
   Variant6434 i;
   alias i this;

   void opDispatch(string name)()
   {
   }
}

void test6434()
{
   A6434 a;
   a.weird; // no property 'weird' for type 'VariantN!(maxSize)'
}

/**************************************/
// 6366

void test6366()
{
    struct Zip
    {
        string str;
        size_t i;
        this(string s)
        {
            str = s;
        }
        @property const bool empty()
        {
            return i == str.length;
        }
        @property Tup!(size_t, char) front()
        {
            return typeof(return)(i, str[i]);
        }
        void popFront()
        {
            ++i;
        }
    }

    foreach (i, c; Zip("hello"))
    {
        switch (i)
        {
            case 0: assert(c == 'h');   break;
            case 1: assert(c == 'e');   break;
            case 2: assert(c == 'l');   break;
            case 3: assert(c == 'l');   break;
            case 4: assert(c == 'o');   break;
            default:assert(0);
        }
    }

    auto range(F...)(F field)
    {
        static struct Range {
            F field;
            bool empty = false;
            Tup!F front() { return typeof(return)(field); }
            void popFront(){ empty = true; }
        }
        return Range(field);
    }

    foreach (i, t; range(10, tup("str", [1,2]))){
        static assert(is(typeof(i) == int));
        static assert(is(typeof(t) == Tup!(string, int[])));
        assert(i == 10);
        assert(t == tup("str", [1,2]));
    }
    auto r1 = range(10, "str", [1,2]);
    auto r2 = range(tup(10, "str"), [1,2]);
    auto r3 = range(10, tup("str", [1,2]));
    auto r4 = range(tup(10, "str", [1,2]));
    alias Seq!(r1, r2, r3, r4) ranges;
    foreach (n, _; ranges)
    {
        foreach (i, s, a; ranges[n]){
            static assert(is(typeof(i) == int));
            static assert(is(typeof(s) == string));
            static assert(is(typeof(a) == int[]));
            assert(i == 10);
            assert(s == "str");
            assert(a == [1,2]);
        }
    }
}

/**********************************************/
// Bugzill 6759

struct Range
{
    size_t front() { return 0; }
    void popFront() { empty = true; }
    bool empty;
}

struct ARange
{
    Range range;
    alias range this;
}

void test6759()
{
    ARange arange;
    assert(arange.front == 0);
    foreach(e; arange)
    {
        assert(e == 0);
    }
}

/**********************************************/
// 6479

struct Memory6479
{
    mixin Wrapper6479!();
}
struct Image6479
{
    Memory6479 sup;
    alias sup this;
}
mixin template Wrapper6479()
{
}

/**********************************************/
// 6832

void test6832()
{
	static class Foo { }
	static struct Bar { Foo foo; alias foo this; }
    Bar bar;
    bar = new Foo;          // ok
    assert(bar !is null);   // ng

    struct Int { int n; alias n this; }
    Int a;
    int b;
    auto c = (true ? a : b);    // TODO
    assert(c == a);
}

/**********************************************/
// 6928

void test6928()
{
    struct T { int* p; } // p is necessary.
    T tx;

    struct S {
        T get() const { return tx; }
        alias get this;
    }

    immutable(S) s;
    immutable(T) t;
    static assert(is(typeof(1? s:t))); // ok.
    static assert(is(typeof(1? t:s))); // ok.
    static assert(is(typeof(1? s:t)==typeof(1? t:s))); // fail.

    auto x = 1? t:s; // ok.
    auto y = 1? s:t; // compile error.
}

/**********************************************/
// 6929

struct S6929
{
    T6929 get() const { return T6929.init; }
    alias get this;
}
struct T6929
{
    S6929 get() const { return S6929.init; }
    alias get this;
}
void test6929()
{
    T6929 t;
    S6929 s;
    static assert(!is(typeof(1? t:s)));
}

/***************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test4773();
    test5188();
    test6();
    test2781();
    test6546();
    test6736();
    test2777a();
    test2777b();
    test6508();
    test6369a();
    test6369b();
    test6369c();
    test6369d();
    test6434();
    test6366();
    test6759();
    test6832();
    test6928();
    test6929();

    printf("Success\n");
    return 0;
}
