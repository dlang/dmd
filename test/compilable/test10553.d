import imports.test10553;

void main()
{
    static assert(!__traits(compiles, a));
    static assert(!__traits(compiles, E.a));
    // Waiting for 10498
    //static assert(!__traits(compiles, E.b));
    static assert(__traits(compiles, b));
    static assert(__traits(compiles, c));
}
