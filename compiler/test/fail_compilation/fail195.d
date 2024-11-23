/*
TEST_OUTPUT:
---
fail_compilation/fail195.d(24): Error: struct `Foo` does not overload ()
    next(); // Error: structliteral has no effect in expression (Foo(0))
        ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1384
// Compiler segfaults when using struct variable like a function with no opCall member.
struct Foo
{
    union
    {
        int a;
        int b;
    }
}

void bla()
{
    Foo next;
    next(); // Error: structliteral has no effect in expression (Foo(0))
}
