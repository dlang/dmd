// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail_casting.d(116): Error: cannot cast expression `x` of type `short[2]` to `int[2]` because of different sizes
    auto y = cast(int[2])x;     // error
                         ^
fail_compilation/fail_casting.d(123): Error: cannot cast expression `null` of type `typeof(null)` to `S1`
    { auto x = cast(S1)null; }
                       ^
fail_compilation/fail_casting.d(124): Error: cannot cast expression `null` of type `typeof(null)` to `S2`
    { auto x = cast(S2)null; }
                       ^
fail_compilation/fail_casting.d(125): Error: cannot cast expression `s1` of type `S1` to `typeof(null)`
    { S1 s1; auto x = cast(typeof(null))s1; }
                                        ^
fail_compilation/fail_casting.d(126): Error: cannot cast expression `s2` of type `S2` to `typeof(null)`
    { S2 s2; auto x = cast(typeof(null))s2; }
                                        ^
fail_compilation/fail_casting.d(132): Error: cannot cast expression `x` of type `Object[]` to `object.Object`
    { Object[]  x; auto y = cast(Object)x; }
                                        ^
fail_compilation/fail_casting.d(133): Error: cannot cast expression `x` of type `Object[2]` to `object.Object`
    { Object[2] x; auto y = cast(Object)x; }
                                        ^
fail_compilation/fail_casting.d(135): Error: cannot cast expression `x` of type `object.Object` to `Object[]`
    { Object x; auto y = cast(Object[] )x; }
                                        ^
fail_compilation/fail_casting.d(136): Error: cannot cast expression `x` of type `object.Object` to `Object[2]`
    { Object x; auto y = cast(Object[2])x; }
                                        ^
fail_compilation/fail_casting.d(142): Error: cannot cast expression `x` of type `int[1]` to `int`
    { int[1]   x; auto y = cast(int     ) x; }
                                          ^
fail_compilation/fail_casting.d(143): Error: cannot cast expression `x` of type `int` to `int[1]`
    { int      x; auto y = cast(int[1]  ) x; }
                                          ^
fail_compilation/fail_casting.d(144): Error: cannot cast expression `x` of type `float[1]` to `int`
    { float[1] x; auto y = cast(int     ) x; }
                                          ^
fail_compilation/fail_casting.d(145): Error: cannot cast expression `x` of type `int` to `float[1]`
    { int      x; auto y = cast(float[1]) x; }
                                          ^
fail_compilation/fail_casting.d(148): Error: cannot cast expression `x` of type `int[]` to `int`
    { int[]   x; auto y = cast(int    ) x; }
                                        ^
fail_compilation/fail_casting.d(149): Error: cannot cast expression `x` of type `int` to `int[]`
    { int     x; auto y = cast(int[]  ) x; }
                                        ^
fail_compilation/fail_casting.d(150): Error: cannot cast expression `x` of type `float[]` to `int`
    { float[] x; auto y = cast(int    ) x; }
                                        ^
fail_compilation/fail_casting.d(151): Error: cannot cast expression `x` of type `int` to `float[]`
    { int     x; auto y = cast(float[]) x; }
                                        ^
fail_compilation/fail_casting.d(160): Error: cannot cast expression `x` of type `int` to `fail_casting.test11485.C`
    { int x; auto y = cast(C)x; }
                             ^
fail_compilation/fail_casting.d(161): Error: cannot cast expression `x` of type `int` to `fail_casting.test11485.I`
    { int x; auto y = cast(I)x; }
                             ^
fail_compilation/fail_casting.d(164): Error: cannot cast expression `x` of type `fail_casting.test11485.C` to `int`
    { C x; auto y = cast(int)x; }
                             ^
fail_compilation/fail_casting.d(165): Error: cannot cast expression `x` of type `fail_casting.test11485.I` to `int`
    { I x; auto y = cast(int)x; }
                             ^
fail_compilation/fail_casting.d(170): Error: cannot cast expression `x` of type `typeof(null)` to `int[2]`
    { typeof(null) x; auto y = cast(int[2])x; }
                                           ^
fail_compilation/fail_casting.d(171): Error: cannot cast expression `x` of type `int[2]` to `typeof(null)`
    { int[2] x;       auto y = cast(typeof(null))x; }
                                                 ^
fail_compilation/fail_casting.d(177): Error: cannot cast expression `x` of type `S` to `int*`
    { S     x; auto y = cast(int*)x; }
                                  ^
fail_compilation/fail_casting.d(179): Error: cannot cast expression `x` of type `void*` to `S`
    { void* x; auto y = cast(S)x; }
                               ^
fail_compilation/fail_casting.d(187): Error: cannot cast expression `mi` of type `MyInt14154` to `MyUbyte14154` because of different sizes
    ubyte t = cast(MyUbyte14154)mi;
                                ^
fail_compilation/fail_casting.d(215): Error: cannot cast expression `point` of type `Tuple14093!(int, "x", int, "y")` to `object.Object`
    auto newPoint = cast(Object)(point);
                                 ^
fail_compilation/fail_casting.d(221): Error: cannot cast expression `p` of type `void*` to `char[]`
    auto arr = cast(char[])p;
                           ^
fail_compilation/fail_casting.d(222): Error: cannot cast expression `p` of type `void*` to `char[2]`
    char[2] sarr = cast(char[2])p;
                                ^
fail_compilation/fail_casting.d(235): Error: cannot cast expression `c` of type `fail_casting.test14629.C` to `typeof(null)`
    { auto x = cast(N)c;  }
                      ^
fail_compilation/fail_casting.d(236): Error: cannot cast expression `p` of type `int*` to `typeof(null)`
    { auto x = cast(N)p;  }
                      ^
fail_compilation/fail_casting.d(237): Error: cannot cast expression `da` of type `int[]` to `typeof(null)`
    { auto x = cast(N)da; }
                      ^
fail_compilation/fail_casting.d(238): Error: cannot cast expression `aa` of type `int[int]` to `typeof(null)`
    { auto x = cast(N)aa; }
                      ^
fail_compilation/fail_casting.d(239): Error: cannot cast expression `fp` of type `int function()` to `typeof(null)`
    { auto x = cast(N)fp; }
                      ^
fail_compilation/fail_casting.d(240): Error: cannot cast expression `dg` of type `int delegate()` to `typeof(null)`
    { auto x = cast(N)dg; }
                      ^
---
*/
void test3133()
{
    short[2] x = [1, 2];
    auto y = cast(int[2])x;     // error
}

void test9904()
{
    static struct S1 { size_t m; }
    static struct S2 { size_t m; byte b; }
    { auto x = cast(S1)null; }
    { auto x = cast(S2)null; }
    { S1 s1; auto x = cast(typeof(null))s1; }
    { S2 s2; auto x = cast(typeof(null))s2; }
}

void test10646()
{
    // T[] or T[n] --> Tclass
    { Object[]  x; auto y = cast(Object)x; }
    { Object[2] x; auto y = cast(Object)x; }
    // T[] or T[n] <-- Tclass
    { Object x; auto y = cast(Object[] )x; }
    { Object x; auto y = cast(Object[2])x; }
}

void test11484()
{
    // Tsarray <--> integer
    { int[1]   x; auto y = cast(int     ) x; }
    { int      x; auto y = cast(int[1]  ) x; }
    { float[1] x; auto y = cast(int     ) x; }
    { int      x; auto y = cast(float[1]) x; }

    // Tarray <--> integer
    { int[]   x; auto y = cast(int    ) x; }
    { int     x; auto y = cast(int[]  ) x; }
    { float[] x; auto y = cast(int    ) x; }
    { int     x; auto y = cast(float[]) x; }
}

void test11485()
{
    class C {}
    interface I {}

    // https://issues.dlang.org/show_bug.cgi?id=11485 TypeBasic --> Tclass
    { int x; auto y = cast(C)x; }
    { int x; auto y = cast(I)x; }

    // https://issues.dlang.org/show_bug.cgi?id=7472 TypeBasic <-- Tclass
    { C x; auto y = cast(int)x; }
    { I x; auto y = cast(int)x; }
}

void test8179()
{
    { typeof(null) x; auto y = cast(int[2])x; }
    { int[2] x;       auto y = cast(typeof(null))x; }
}

void test13959()
{
    struct S { int* p; }
    { S     x; auto y = cast(int*)x; }
    { int*  x; auto y = cast(S)x; }     // no error so it's rewritten as: S(x)
    { void* x; auto y = cast(S)x; }
}

struct MyUbyte14154 { ubyte x; alias x this; }
struct MyInt14154   {   int x; alias x this; }
void test14154()
{
    MyInt14154 mi;
    ubyte t = cast(MyUbyte14154)mi;
}

alias TypeTuple14093(T...) = T;
struct Tuple14093(T...)
{
    static if (T.length == 4)
    {
        alias Types = TypeTuple14093!(T[0], T[2]);

        Types expand;

        @property ref inout(Tuple14093!Types) _Tuple_super() inout @trusted
        {
            return *cast(typeof(return)*) &(expand[0]);
        }
        alias _Tuple_super this;
    }
    else
    {
        alias Types = T;
        Types expand;
        alias expand this;
    }
}
void test14093()
{
    Tuple14093!(int, "x", int, "y") point;
    auto newPoint = cast(Object)(point);
}

void test14596()
{
    void* p = null;
    auto arr = cast(char[])p;
    char[2] sarr = cast(char[2])p;
}

void test14629()
{
    alias P = int*;             P p;
    alias DA = int[];           DA da;
    alias AA = int[int];        AA aa;
    alias FP = int function();  FP fp;
    alias DG = int delegate();  DG dg;
    class C {}                  C c;
    alias N = typeof(null);

    { auto x = cast(N)c;  }
    { auto x = cast(N)p;  }
    { auto x = cast(N)da; }
    { auto x = cast(N)aa; }
    { auto x = cast(N)fp; }
    { auto x = cast(N)dg; }
}
