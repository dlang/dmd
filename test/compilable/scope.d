/*
 PERMUTE_FIXME_ARGS: -preview=dip1000
*/

/// https://issues.dlang.org/show_bug.cgi?id=17408
void f(in scope int x) {}
void g(scope in int x) {}

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

