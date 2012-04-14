import imports.test7327a, imports.test7327b;

template TT(Args...) { alias Args TT; }
void test()
{
    foreach(T; TT!(int, short, byte))
    {
        static assert(!__traits(compiles, foo(cast(T)0)));
        static assert( __traits(compiles, bar(cast(T)0)));
        static assert(!__traits(compiles, baz(cast(T)0)));
        static assert( __traits(compiles, buz(cast(T)0)));
    }
}
