extern(C) void vf(int x, ...)
{
    import core.stdc.stdarg;
    va_list args;

    va_start(args, x);
    auto s = va_arg!(const(char)*)(args);
    assert(s[0..2] == "hi");
    va_end(args);
}

void main()
{
    vf(0, "hi");

    string s;
    static assert(!__traits(compiles, vf(0, s)));
}

