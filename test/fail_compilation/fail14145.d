// https://issues.dlang.org/show_bug.cgi?id=14145

/*
TEST_OUTPUT:
---
fail_compilation/fail14145.d(17): Error: `writeln` is not defined, perhaps `import std.stdio;` is needed?
fail_compilation/fail14145.d(23): Error: template instance `fail14145.A.opDispatch!"foo"` error instantiating
---
*/

void foo() {}

struct A
{
    auto opDispatch(string op)()
    {
        writeln;
    }
}

void test()
{
    A.init.foo();
}
