import core.runtime;

struct Num
{
    pragma(inline, false) this(uint val)
    {
        this.val = val;
    }

    uint val;
}

pragma(inline, false) Num* foo(uint val)
{
    return new Num(val);
}

__gshared uint sum;

void main(string[] args)
{
    trace_setlogfilename(args[1]);
    trace_setdeffilename(args[2]);
    profilegc_setlogfilename(args[3]);
    foreach (uint i; 0 .. 1_000)
        sum += foo(i).val;
}
