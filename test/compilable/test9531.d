// REQUIRED_ARGS: -unittest
module Fix9531;

unittest
{
    struct S { }
    enum s = __traits(parent, S).stringof;
    static assert(s == "module Fix9531");
}

void main()
{
}
