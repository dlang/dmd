// https://issues.dlang.org/show_bug.cgi?id=21451

void f(int a : 1)() { }
void f(int b : 2)(int x) { }

void main()
{
    static assert( __traits(compiles, f!1 ));
    static assert( __traits(compiles, f!1() ));
    static assert( __traits(compiles, f!2(2) ));
    static assert(!__traits(compiles, f!(1, 2) ));
    static assert(!__traits(compiles, f!() )); // ???
    static assert(!__traits(compiles, { f!(); }));
}
