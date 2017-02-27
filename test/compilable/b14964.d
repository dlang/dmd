template foo(alias S, int W)
{
    static assert( __traits(isAlias, S));
    static assert(!__traits(isAlias, W));
}

struct S(T)
{
    static assert( __traits(isAlias, T));
}

void main()
{
    int var;
    alias par = var;
    alias foo1 = foo!(S,4);
    auto s = new S!int;
    static assert( __traits(isAlias, par));
    static assert( __traits(isAlias, foo1));
    static assert(!__traits(isAlias, var));
    static assert(!__traits(isAlias, s));
}
