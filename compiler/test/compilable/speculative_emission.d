/*
LINK:
*/

import imports.speculative_emission;

struct Foo(T) { ~this() {} }

enum b = __traits(compiles, { auto a = [Foo!int()]; });
enum c = __traits(compiles, { Foo!int[string] aa; auto d = aa.dup; });

// https://github.com/dlang/dmd/issues/22848
mixin template Main(alias mainFunction) {}

mixin Main!(()
{
    static bool pred(char c) => false;
    accept!pred;
});

char accept(alias pred)() => pred(0);

void main()
{
    fp();
    F();
}
