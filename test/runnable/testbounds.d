// PERMUTE_ARGS:

// Test array bounds checking

import core.exception;
extern(C) int printf(const char*, ...);

/******************************************/

const int foos[10] = [1,2,3,4,5,6,7,8,9,10];
const int food[]   = [21,22,23,24,25,26,27,28,29,30];
const int *foop    = cast(int*) foos;

static int x = 2;

int index()
{
    return x++;
}

int tests(int i)
{
    return foos[index()];
}

int testd(int i)
{
    return food[index()];
}

int testp(int i)
{
    return foop[i];
}

const(int)[] slices(int lwr, int upr)
{
    return foos[lwr .. upr];
}

const(int)[] sliced(int lwr, int upr)
{
    return food[lwr .. upr];
}

const(int)[] slicep(int lwr, int upr)
{
    return foop[lwr .. upr];
}

void test1()
{
    int i;

    i = tests(0);
    assert(i == 3);

    i = testd(0);
    assert(i == 24);

    i = testp(1);
    assert(i == 2);

    x = 10;
    try
    {
        i = tests(0);
    }
    catch (RangeError a)
    {
        i = 73;
    }
    assert(i == 73);

    x = -1;
    try
    {
        i = testd(0);
    }
    catch (RangeError a)
    {
        i = 37;
    }
    assert(i == 37);

    const(int)[] r;

    r = slices(3,5);
    assert(r[0] == foos[3]);
    assert(r[1] == foos[4]);

    r = sliced(3,5);
    assert(r[0] == food[3]);
    assert(r[1] == food[4]);

    r = slicep(3,5);
    assert(r[0] == foos[3]);
    assert(r[1] == foos[4]);

    try
    {
        i = 7;
        r = slices(5,3);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    try
    {
        i = 7;
        r = slices(5,11);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    try
    {
        i = 7;
        r = sliced(5,11);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    try
    {
        i = 7;
        r = slicep(5,3);
    }
    catch (RangeError a)
    {
        i = 53;
    }
    assert(i == 53);

    // Take side effects into account
    x = 1;
    r = foos[index() .. 3];
    assert(x == 2);
    assert(r[0] == foos[1]);
    assert(r[1] == foos[2]);

    r = foos[1 .. index()];
    assert(r.length == 1);
    assert(x == 3);
    assert(r[0] == foos[1]);

    x = 1;
    r = food[index() .. 3];
    assert(x == 2);
    assert(r[0] == food[1]);
    assert(r[1] == food[2]);

    r = food[1 .. index()];
    assert(r.length == 1);
    assert(x == 3);
    assert(r[0] == food[1]);

    x = 1;
    r = foop[index() .. 3];
    assert(x == 2);
    assert(r[0] == foop[1]);
    assert(r[1] == foop[2]);

    r = foop[1 .. index()];
    assert(r.length == 1);
    assert(x == 3);
    assert(r[0] == foop[1]);
}

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

    //void hoo(size_t dim)(char[dim]) { static assert(dim == 2); }
    //hoo(str[0 .. 2]);
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

    void hoo(size_t dim)(int[dim]) { static assert(dim == 2); }
    hoo(da[0 .. 2]);
}

/******************************************/

int main()
{
    test1();
    test3652();
    test3652a();
    test3652b();

    printf("Success\n");
    return 0;
}
