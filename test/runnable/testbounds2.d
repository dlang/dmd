// PERMUTE_ARGS:

// Test compile time boundaries checking

extern(C) int printf(const char*, ...);

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

int main()
{
    test3652();
    test3652a();
    test3652b();

    printf("Success\n");
    return 0;
}
