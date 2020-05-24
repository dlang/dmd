// REQUIRED_ARGS: -preview=dip1000

// https://github.com/dlang/dmd/pull/9374

struct OnlyResult
{
    this(return scope ref int v2) @system;

    void* data;
}

OnlyResult foo(return scope ref int v2) @system;

OnlyResult only(int y)
{
    if (y)
        return OnlyResult(y);
    return foo(y);
}
