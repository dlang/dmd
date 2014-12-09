// REQUIRED_ARGS:

// Test compile time boundaries checking

extern(C) int printf(const char*, ...);

template TypeTuple(T...) { alias T TypeTuple; }

/******************************************/
// 3652

void test3652()
{
    int foo(int[4] x)
    {
        return x[0] + x[1] * x[2] - x[3];
    }

    int[] xs = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];

    // simple case
    foo(xs[0 .. 4]);

  version(none)
  {
    // Need deformation of formula and detection of base point
    int x = 0;
    int y = 0;
    foreach (i; 0 .. 4)
    {
        x += foo(xs[i .. i + 4]);
        y += foo(xs[(i*4+10)/2 .. (i*8>>1)/2+9]);
        // lwr = (i*4 + 10)/2 = i*4/2 + 10/2            = (i*2+5)
        // upr = (i*8>>1)/2 + 5 = (i*4/2) + 5 = i*2 + 9 = (i*2+5) + 4
    }
    assert(x == (0,1,2,3) + (1,2,3, 4) + (2, 3, 4, 5) + ( 3, 4, 5, 6));
    assert(y == (5,6,7,8) + (7,8,9,10) + (9,10,11,12) + (11,12,13,14));
  }
}

void test3652a() @safe
{
    string str = "aaaabbbbccccdddd";
    //printf("str.ptr = %p\n", str.ptr);

    void foo(ref const(char)[16] buf)
    {
        //printf("buf.ptr = %p\n", buf.ptr);
        assert(buf.ptr is str.ptr);
    }

    // can check length at runtime
    assert(str.length == 16);

    // compiler can check the length of string literal, so
    // conversion from immutable(char)[] to ref const(char)[16] is allowed;
    static assert(__traits(compiles, foo("aaaabbbbccccdddd")));

    // OK, correctly rejected by the compiler.
    static assert(!__traits(compiles, foo(str[])));

    // Ugly, furthermore does not work in safe code!
    //foo(*cast(const(char)[16]*)(str[0..16].ptr));

    // New: compiler can check the length of slice, but currently it is not allowed.
    enum size_t m = 0;
    size_t calc(){ return 0; }
    foo(str[0 .. 16]);
    foo(str[m .. 16]);
  //foo(str[calc() .. 16]); // with CTFE

    // If boundaries cannot be calculated in compile time, it's rejected.
    size_t n;
    size_t calc2(){ return n; }
    static assert(!__traits(compiles, foo(str[n .. 16])));
    static assert(!__traits(compiles, foo(str[calc2() .. 16])));

    void hoo1(size_t dim)(char[dim]) { static assert(dim == 2); }
    void hoo2(char[2]) {}
    void hoo3(size_t dim)(ref char[dim]) {}
    void hoo4(ref char[2]) {}
    hoo1(str[0 .. 2]);
    hoo2(str[0 .. 2]);
    static assert(!__traits(compiles, hoo3(str[0 .. 2])));
    static assert(!__traits(compiles, hoo4(str[0 .. 2])));
}
void test3652b() @safe
{
    int[] da = [1,2,3,4,5];

    void bar(int[3] sa1, ref int[3] sa2)
    {
        assert(sa1 == [1,2,3] && sa1.ptr !is da.ptr);
        assert(sa2 == [1,2,3] && sa2.ptr  is da.ptr);
    }
    bar(da[0..3], da[0..3]);
    static assert(!__traits(compiles, bar(da[0..4], da[0..4])));

    void baz1(T)(T[3] sa1, ref T[3] sa2)
    {
        assert(sa1 == [1,2,3] && sa1.ptr !is da.ptr);
        assert(sa2 == [1,2,3] && sa2.ptr  is da.ptr);
    }
    void baz2(T, size_t dim)(T[dim] sa1, ref T[dim] sa2, size_t result)
    {
        assert(dim == result);
        static if (dim == 3)
        {
            assert(sa1 == [1,2,3] && sa1.ptr !is da.ptr);
            assert(sa2 == [1,2,3] && sa2.ptr  is da.ptr);
        }
        else
        {
            assert(sa1 == [1,2,3,4] && sa1.ptr !is da.ptr);
            assert(sa2 == [1,2,3,4] && sa2.ptr  is da.ptr);
        }
    }
    baz1(da[0..3], da[0..3]);
    static assert(!__traits(compiles, baz1(da[0..4], da[0..4])));
    baz2(da[0..3], da[0..3], 3);
    baz2(da[0..4], da[0..4], 4);

    void hoo1(size_t dim)(int[dim]) { static assert(dim == 2); }
    void hoo2(int[2]) {}
    void hoo3(size_t dim)(ref int[dim]) {}
    void hoo4(ref int[2]) {}
    hoo1(da.idup[0 .. 2]);
    hoo2(da.idup[0 .. 2]);
    static assert(!__traits(compiles, hoo3(da.idup[0 .. 2])));
    static assert(!__traits(compiles, hoo4(da.idup[0 .. 2])));
}

/**********************************/
// 9654

auto foo9654a(ref           char[8] str) { return str; }
auto foo9654b(ref     const char[8] str) { return str; }
auto foo9654c(ref immutable char[8] str) { return str; }
static assert(!is(typeof(foo9654a("testinfo"))));
static assert( is(typeof(foo9654b("testinfo")) ==     const char[8]));
static assert( is(typeof(foo9654c("testinfo")) == immutable char[8]));

auto bar9654a(T)(ref           T[8] str) { return str; static assert(is(T == immutable char)); }
auto bar9654b(T)(ref     const T[8] str) { return str; static assert(is(T ==           char)); }
auto bar9654c(T)(ref immutable T[8] str) { return str; static assert(is(T ==           char)); }
static assert( is(typeof(bar9654a("testinfo")) == immutable char[8]));
static assert( is(typeof(bar9654b("testinfo")) ==     const char[8]));
static assert( is(typeof(bar9654c("testinfo")) == immutable char[8]));

auto baz9654a(T, size_t dim)(ref           T[dim] str) { return str; static assert(is(T == immutable char)); }
auto baz9654b(T, size_t dim)(ref     const T[dim] str) { return str; static assert(is(T ==           char)); }
auto baz9654c(T, size_t dim)(ref immutable T[dim] str) { return str; static assert(is(T ==           char)); }
static assert( is(typeof(baz9654a("testinfo")) == immutable char[8]));
static assert( is(typeof(baz9654b("testinfo")) ==     const char[8]));
static assert( is(typeof(baz9654c("testinfo")) == immutable char[8]));

/******************************************/
// 9712

auto func9712(T)(T[2] arg) { return arg; }
static assert(is(typeof(func9712([1,2])) == int[2]));

auto deduceLength9712(T,size_t n)(T[n] a) { return a; }
static assert(is(typeof(deduceLength9712([1,2,3])) == int[3]));

/******************************************/
// 9743

void test9743()
{
    //    +-Char
    //    |+-Immutable or Const or Mutable
    //    ||+-Value or Ref
    //    |||+-Function                           or +-Template
    void fCIVF(    immutable  char[4]) {}   void fCIVT()(    immutable  char[4]) {}
    void fCCVF(        const  char[4]) {}   void fCCVT()(        const  char[4]) {}
    void fCMVF(               char[4]) {}   void fCMVT()(               char[4]) {}
    void fCIRF(ref immutable  char[4]) {}   void fCIRT()(ref immutable  char[4]) {}
    void fCCRF(ref     const  char[4]) {}   void fCCRT()(ref     const  char[4]) {}
    void fCMRF(ref            char[4]) {}   void fCMRT()(ref            char[4]) {}
    alias fcOK = TypeTuple!(fCIVF, fCIVT, fCCVF, fCCVT, fCMVF, fCMVT, fCIRF, fCIRT, fCCRF, fCCRT);
    foreach (f; fcOK)                                   f("1234" )   ;
    foreach (f; fcOK)                                   f("1234"c)   ;
    foreach (f; fcOK) static assert(!__traits(compiles, f("1234"w) ));
    foreach (f; fcOK) static assert(!__traits(compiles, f("1234"d) ));
    alias fcNG = TypeTuple!(fCMRF, fCMRT);  // cannot hold immutable data by mutable ref
    foreach (f; fcNG) static assert(!__traits(compiles, f("1234" ) ));
    foreach (f; fcNG) static assert(!__traits(compiles, f("1234"c) ));
    foreach (f; fcNG) static assert(!__traits(compiles, f("1234"w) ));
    foreach (f; fcNG) static assert(!__traits(compiles, f("1234"d) ));

    //    +-Wchar
    void fWIVF(    immutable wchar[4]) {}   void fWIVT()(    immutable wchar[4]) {}
    void fWCVF(        const wchar[4]) {}   void fWCVT()(        const wchar[4]) {}
    void fWMVF(              wchar[4]) {}   void fWMVT()(              wchar[4]) {}
    void fWIRF(ref immutable wchar[4]) {}   void fWIRT()(ref immutable wchar[4]) {}
    void fWCRF(ref     const wchar[4]) {}   void fWCRT()(ref     const wchar[4]) {}
    void fWMRF(ref           wchar[4]) {}   void fWMRT()(ref           wchar[4]) {}
    alias fwOK = TypeTuple!(fWIVF, fWIVT, fWCVF, fWCVT, fWMVF, fWMVT, fWIRF, fWIRT, fWCRF, fWCRT);
    foreach (f; fwOK)                                   f("1234" )   ;
    foreach (f; fwOK) static assert(!__traits(compiles, f("1234"c) ));
    foreach (f; fwOK)                                   f("1234"w)   ;
    foreach (f; fwOK) static assert(!__traits(compiles, f("1234"d) ));
    alias fwNG = TypeTuple!(fWMRF, fWMRT);  // cannot hold immutable data by mutable ref
    foreach (f; fwNG) static assert(!__traits(compiles, f("1234" ) ));
    foreach (f; fwNG) static assert(!__traits(compiles, f("1234"c) ));
    foreach (f; fwNG) static assert(!__traits(compiles, f("1234"w) ));
    foreach (f; fwNG) static assert(!__traits(compiles, f("1234"d) ));

    //    +-Dchar
    void fDIVF(    immutable dchar[4]) {}   void fDIVT()(    immutable dchar[4]) {}
    void fDCVF(        const dchar[4]) {}   void fDCVT()(        const dchar[4]) {}
    void fDMVF(              dchar[4]) {}   void fDMVT()(              dchar[4]) {}
    void fDIRF(ref immutable dchar[4]) {}   void fDIRT()(ref immutable dchar[4]) {}
    void fDCRF(ref     const dchar[4]) {}   void fDCRT()(ref     const dchar[4]) {}
    void fDMRF(ref           dchar[4]) {}   void fDMRT()(ref           dchar[4]) {}
    alias fdOK = TypeTuple!(fDIVF, fDIVT, fDCVF, fDCVT, fDMVF, fDMVT, fDIRF, fDIRT, fDCRF, fDCRT);
    foreach (f; fdOK)                                   f("1234" )   ;
    foreach (f; fdOK) static assert(!__traits(compiles, f("1234"c) ));
    foreach (f; fdOK) static assert(!__traits(compiles, f("1234"w) ));
    foreach (f; fdOK)                                   f("1234"d)   ;
    alias fdNG = TypeTuple!(fDMRF, fDMRT);  // cannot hold immutable data by mutable ref
    foreach (f; fdNG) static assert(!__traits(compiles, f("1234" ) ));
    foreach (f; fdNG) static assert(!__traits(compiles, f("1234"c) ));
    foreach (f; fdNG) static assert(!__traits(compiles, f("1234"w) ));
    foreach (f; fdNG) static assert(!__traits(compiles, f("1234"d) ));
}

/******************************************/
// 9747

void foo9747A(T)(T[4]) {}
void foo9747C(size_t dim)(char[dim]) {}
void foo9747W(size_t dim)(wchar[dim]) {}
void foo9747D(size_t dim)(dchar[dim]) {}

void test9747()
{
    foo9747A("abcd"c);
    foo9747A("abcd"w);
    foo9747A("abcd"d);
    foo9747C("abcd"c);
    foo9747W("abcd"w);
    foo9747D("abcd"d);
}

/******************************************/
// 12876

void test12876()
{
    void foo(int[4] b) {}
    void bar(size_t n)(int[n] c) { static assert(n == 4); }

    int[5] a;
    foo(a[1 .. $]); // OK
    bar(a[1 .. $]); // OK <- Error
}

/******************************************/
// 13775

void test13775()
{
    ubyte[4] ubytes = [1,2,3,4];

    // CT-known slicing (issue 3652)
    auto ok1 = cast(ubyte[2]) ubytes[0 .. 2];
    assert(ok1 == [1, 2]);

    // CT-known slicing with implicit conversion of SliceExp::e1 (issue 13154)
    enum double[] arr = [1.0, 2.0, 3.0];
    auto ok2 = cast(float[2]) [1.0, 2.0, 3.0][0..2];
    auto ok3 = cast(float[2]) arr[1..3];    // currently this is accepted
    assert(ok2 == [1f, 2f]);
    assert(ok3 == [2f, 3f]);

    // CT-known slicing with type coercing (issue 13775)
    auto ok4 = cast( byte[2]) ubytes[0 .. 2];   // CT-known slicing + type coercing
    auto ok5 = cast(short[1]) ubytes[0 .. 2];   // CT-known slicing + type coercing
    assert(ok4 == [1, 2]);
    version(LittleEndian) assert(ok5 == [0x0201]);
    version(   BigEndian) assert(ok5 == [0x0102]);
}

/******************************************/

int main()
{
    test3652();
    test3652a();
    test3652b();
    test9743();
    test9747();
    test13775();

    printf("Success\n");
    return 0;
}
