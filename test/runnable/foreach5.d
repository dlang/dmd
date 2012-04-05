
extern(C) int printf(const char* fmt, ...);

/***************************************/

void test1()
{
    char[] a;

    int foo()
    {
        printf("foo\n");
        a ~= "foo";
        return 10;
    }

    foreach (i; 0 .. foo())
    {
        printf("%d\n", i);
        a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789");

    foreach_reverse (i; 0 .. foo())
    {
        printf("%d\n", i);
        a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789foo9876543210");
}

/***************************************/
// 2411

struct S2411
{
    int n;
    string s;
}

void test2411()
{
    S2411 s;
    assert(s.n == 0);
    assert(s.s == "");
    foreach (i, ref e; s.tupleof)
    {
        static if (i == 0)
            e = 10;
        static if (i == 1)
            e = "str";
    }
    assert(s.n == 10);
    assert(s.s == "str");
}

/***************************************/
// 2442

template canForeach(T, E)
{
    enum canForeach = __traits(compiles,
    {
        foreach(a; new T)
        {
            static assert(is(typeof(a) == E));
        }
    });
}

void test2442()
{
    struct S1
    {
        int opApply(int delegate(ref const(int) v) dg) const { return 0; }
        int opApply(int delegate(ref int v) dg)              { return 0; }
    }
          S1 ms1;
    const S1 cs1;
    foreach (x; ms1) { static assert(is(typeof(x) ==       int)); }
    foreach (x; cs1) { static assert(is(typeof(x) == const int)); }

    struct S2
    {
        int opApply(int delegate(ref  int v) dg) { return 0; }
        int opApply(int delegate(ref long v) dg) { return 0; }
    }
    S2 ms2;
    static assert(!__traits(compiles, { foreach (    x; ms2) {} }));    // ambiguous
    static assert( __traits(compiles, { foreach (int x; ms2) {} }));

    struct S3
    {
        int opApply(int delegate(ref int v) dg) const        { return 0; }
        int opApply(int delegate(ref int v) dg) shared const { return 0; }
    }
    immutable S3 ms3;
    static assert(!__traits(compiles, { foreach (int x; ms3) {} }));    // ambiguous

    // from https://github.com/D-Programming-Language/dmd/pull/120
    static class C
    {
        int opApply(int delegate(ref              int v) dg)              { return 0; }
        int opApply(int delegate(ref        const int v) dg) const        { return 0; }
        int opApply(int delegate(ref    immutable int v) dg) immutable    { return 0; }
        int opApply(int delegate(ref       shared int v) dg) shared       { return 0; }
        int opApply(int delegate(ref shared const int v) dg) shared const { return 0; }
    }
    static class D
    {
        int opApply(int delegate(ref int v) dg) const        { return 0; }
    }
    static class E
    {
        int opApply(int delegate(ref int v) dg) shared const { return 0; }
    }

    static assert( canForeach!(             C  ,              int  ));
    static assert( canForeach!(       const(C) ,        const(int) ));
    static assert( canForeach!(   immutable(C) ,    immutable(int) ));
    static assert( canForeach!(      shared(C) ,       shared(int) ));
    static assert( canForeach!(shared(const(C)), shared(const(int))));

    static assert( canForeach!(             D  , int));
    static assert( canForeach!(       const(D) , int));
    static assert( canForeach!(   immutable(D) , int));
    static assert(!canForeach!(      shared(D) , int));
    static assert(!canForeach!(shared(const(D)), int));

    static assert(!canForeach!(             E  , int));
    static assert(!canForeach!(       const(E) , int));
    static assert( canForeach!(   immutable(E) , int));
    static assert( canForeach!(      shared(E) , int));
    static assert( canForeach!(shared(const(E)), int));
}

/***************************************/
// 2443

struct S2443
{
    int[] arr;
    int opApply(int delegate(size_t i, ref int v) dg)
    {
        int result = 0;
        foreach (i, ref x; arr)
        {
            if ((result = dg(i, x)) != 0)
                break;
        }
        return result;
    }
}

void test2443()
{
    S2443 s;
    foreach (i, ref v; s) {}
    foreach (i,     v; s) {}
    static assert(!__traits(compiles, { foreach (ref i, ref v; s) {} }));
    static assert(!__traits(compiles, { foreach (ref i,     v; s) {} }));
}

/***************************************/
// 3187

class Collection
{
    int opApply(int delegate(ref Object) a)
    {
        return 0;
    }
}

Object testForeach(Collection level1, Collection level2)
{
    foreach (first; level1) {
        foreach (second; level2)
            return second;
    }
    return null;
}

void test3187()
{
    testForeach(new Collection, new Collection);
}

/***************************************/
// 5605

struct MyRange
{
    int theOnlyOne;

    @property bool empty() const
    {
        return true;
    }

    @property ref int front()
    {
        return theOnlyOne;
    }

    void popFront()
    {}
}

struct MyCollection
{
    MyRange opSlice() const
    {
        return MyRange();
    }
}

void test5605()
{
    auto coll = MyCollection();

    foreach (i; coll) {            // <-- compilation error
        // ...
    }
}

/***************************************/
// 7004

void func7004(A...)(A args)
{
    foreach (i, e; args){}        // OK
    foreach (uint i, e; args){}   // OK
    foreach (size_t i, e; args){} // NG
}
void test7004()
{
    func7004(1, 3.14);
}

/***************************************/
// 7406

template TypeTuple7406(T...)
{
    alias T TypeTuple7406;
}

template foobar7406(T)
{
    enum foobar = 2;
}

void test7406()
{
    foreach (sym; TypeTuple7406!(int, double))     // OK
        pragma(msg, sym.stringof);

    foreach (sym; TypeTuple7406!(foobar7406))      // OK
        pragma(msg, sym.stringof);

    foreach (sym; TypeTuple7406!(test7406))        // OK
        pragma(msg, sym.stringof);

    foreach (sym; TypeTuple7406!(int, foobar7406)) // Error: type int has no value
        pragma(msg, sym.stringof);

    foreach (sym; TypeTuple7406!(int, test7406))   // Error: type int has no value
        pragma(msg, sym.stringof);
}

/***************************************/
// 6659

void test6659()
{
    static struct Iter
    {
        ~this()
        {
            ++_dtor;
        }

        bool opCmp(ref const Iter rhs) { return _pos == rhs._pos; }
        void opUnary(string op:"++")() { ++_pos; }
        size_t _pos;

        static size_t _dtor;
    }

    foreach (ref iter; Iter(0) .. Iter(10))
    {
        assert(Iter._dtor == 0);
    }
    assert(Iter._dtor == 2);

    Iter._dtor = 0; // reset

    for (auto iter = Iter(0), limit = Iter(10); iter != limit; ++iter)
    {
        assert(Iter._dtor == 0);
    }
    assert(Iter._dtor == 2);
}

void test6659a()
{
    auto value = 0;
    try
    {
        for ({scope(success) { assert(value == 1); value = 2;} }  true; )
        {
            value = 1;
            break;
        }
        assert(value == 2);
    }
    catch (Exception e)
    {
        assert(0);
    }
    assert(value == 2);
}

void test6659b()
{
    auto value = 0;
    try
    {
        for ({scope(failure) value = 1;}  true; )
        {
            throw new Exception("");
        }
        assert(0);
    }
    catch (Exception e)
    {
        assert(e);
    }
    assert(value == 1);
}

void test6659c()
{
    auto value = 0;
    try
    {
        for ({scope(exit) value = 1;}  true; )
        {
            throw new Exception("");
        }
        assert(0);
    }
    catch (Exception e)
    {
        assert(e);
    }
    assert(value == 1);
}

/***************************************/
// 7814

struct File7814
{
    ~this(){}
}

struct ByLine7814
{
    File7814 file;

    // foreach interface
    @property bool empty() const    { return true; }
    @property char[] front()        { return null; }
    void popFront(){}
}

void test7814()
{
    int dummy;
    ByLine7814 f;
    foreach (l; f) {
        scope(failure) // 'failure' or 'success' fails, but 'exit' works
            dummy = -1;
        dummy = 0;
    }
}

/***************************************/

int main()
{
    test1();
    test2411();
    test2442();
    test2443();
    test3187();
    test5605();
    test7004();
    test7406();
    test6659();
    test6659a();
    test6659b();
    test6659c();
    test7814();

    printf("Success\n");
    return 0;
}
