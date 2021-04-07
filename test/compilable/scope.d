/*
REQUIRED_ARGS: -preview=dip1000
*/

struct Cache
{
    ubyte[1] v;

    ubyte[] set(ubyte[1] v) return
    {
        return this.v[] = v[];
    }
}

/*********************************/

// https://github.com/dlang/dmd/pull/9220

@safe:

struct OnlyResult
{
    private this(Values)(scope ref Values values)
    {
        this.s = values;
    }

    string s;
}

auto only(Values)(Values vv)
{
    return OnlyResult(vv);
}


void test() @nogc @safe pure
{
    only(null);
}

/************************************/

// https://github.com/dlang/dmd/pull/9220

auto callWrappedOops(scope string dArgs) {

    string callWrappedImpl() {
        return dArgs;
    }
}

/************************************/

struct Constant
{
    int* member;

    this(Repeat!(int*) grid) @safe
    {
        foreach(ref x; grid)
            member = x;

        foreach(ref x; grid)
            x = member;
    }

    int* foo(return scope Repeat!(int*) grid) @safe
    {
        foreach(ref x; grid)
            x = member;

        foreach(ref x; grid)
            return x;

        return null;
    }

    alias Repeat(T...) = T;
}

/************************************/

// https://issues.dlang.org/show_bug.cgi?id=20675

struct D
{
    int pos;
    char* p;
}

void test(scope ref D d) @safe
{
    D[] da;
    da ~= D(d.pos, null);
}

/************************************/

void withEscapes()
{
    static D get() @safe;

    with (get())
    {
    }
}

/************************************/

// https://issues.dlang.org/show_bug.cgi?id=20682

int f1_20682(return scope ref D d) @safe
{
    return d.pos;
}

ref int f2_20682(return scope ref D d) @safe
{
    return d.pos;
}

void test_20682(scope ref D d) @safe
{
    int[] a;
    a ~= f1_20682(d);
    a ~= f2_20682(d);
    a ~= cast(int) d.p;
}
