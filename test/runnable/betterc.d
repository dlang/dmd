/* REQUIRED_ARGS: -betterC
   PERMUTE_ARGS:
 */


void test(int ij)
{
    assert(ij);
#line 100 "anotherfile"
    assert(ij,"it is not zero");
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=17843

struct S
{
    double d = 0.0;
    int[] x;
}

/*******************************************/

extern (C) void main()
{
    test(1);
    test18472();
    testRuntimeLowerings();
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=17605

extern (C) void test17605()
{
    int a;
    enum bool works = __traits(compiles, { a = 1; });
    a = 1;
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=18472

void test18472()
{
    version(D_LP64)
    {
        enum b = typeid(size_t) is typeid(ulong);
    }
    else
    {
        enum b = typeid(size_t) is typeid(uint);
    }

    assert(b);
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=18493

struct S18493
{
    this(this) nothrow { }  // Since this is attributed with `nothrow` there should be no error about using
                            // try-catch with -betterC
    ~this() { }
}

struct S18493_2
{
    S18493 s1;
    S18493 s2;
}

/******************************************************
 * tests to ensure there is sufficient runtime support
 * in imported object.d
 */
mixin template initArray()
{
    static if (is(T == bool))
    {
        T[6] a1 = [true, false, true, true, false, true];
    }
    else static if (is(T == Sint))
    {
        T[6] a1 = [Sint(1), Sint(2), Sint(3), Sint(1), Sint(2), Sint(3)];
    }
    else
    {
        T[6] a1 = [1,2,3,1,2,3];
    }
}

struct Sint
{
    int x;
    this(int v) { x = v;}
}

bool castToLongFailed = false;
extern(C) void castToLongAssertFail(int sig) nothrow @nogc
{
	castToLongFailed = true;
}

void testRuntimeLowerings()
{
    // test call to `object.__equals`
    void test__equals(T)()
    {
        mixin initArray;

        assert(a1[0..3] == a1[3..$]);
    }

    test__equals!int;
    test__equals!uint;
    test__equals!long;
    test__equals!ulong;
    test__equals!short;
    test__equals!ushort;
    test__equals!byte;
    test__equals!dchar;
    test__equals!wchar;
    test__equals!ubyte;
    test__equals!char;
    test__equals!(const char);
    test__equals!bool;
    test__equals!Sint;

    // test call to `object.__cmp`
    void test__cmp(T)()
    {
        mixin initArray;

        assert(a1[0..3] >= a1[3..$]);
        assert(a1[0..3] <= a1[3..$]);
    }

    test__cmp!int;
    test__cmp!uint;
    test__cmp!long;
    test__cmp!ulong;
    test__cmp!short;
    test__cmp!ushort;
    test__cmp!byte;
    test__cmp!dchar;
    test__cmp!wchar;
    test__cmp!ubyte;
    test__cmp!char;
    test__cmp!(const char);
    test__cmp!bool;
    test__cmp!Sint;

    // test call to `object.__switch``
    auto s = "abc";
    switch(s)
    {
        case "abc":
            break;
        default:
            break;
    }

    // test call to `object.__ArrayCast`
    import core.stdc.stdlib : malloc, free, exit;
    import core.stdc.signal;

    byte[] b;
    int[]  i;
    long[] l;

    // We can't actually create dynamic arrays in idiomatic D when
    // compiling with -betterC, so we do it manually.
    auto b_length = cast(size_t*)&b;
    auto b_ptr = cast(void*)(b_length + 1);
    *b_length = int.sizeof * 3;
    b_ptr = malloc(*b_length);

    i = cast(int[])b;
    assert(i.length == 3);

    // size mismatch, should result in an assertion failure
    l = cast(long[])b;
    signal(SIGABRT, &castToLongAssertFail);
    assert(castToLongFailed);

    // No garbage collector in -betterC, we must free memory manually.
    free(b_ptr);

    exit(0);
}
