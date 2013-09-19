import imports.test10552;

void main()
{
    static assert(__traits(compiles, a));
    static assert(!__traits(compiles, b));
    static assert(__traits(compiles, c));
}
