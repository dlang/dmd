import core.runtime;

pragma(inline, false) uint foo(uint val)
{
    return val * 2;
}

__gshared uint sum;

void main(string[] args)
{
    trace_setlogfilename(args[1]);
    trace_setdeffilename(args[2]);
    foreach (uint i; 0 .. 1_000)
        sum += foo(i);

    // Issue 19593
    assert(!("aaa" >= "bbb"));
    assert("aaa" <= "bbb");
}
