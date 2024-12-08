/*
TEST_OUTPUT:
---
fail_compilation/fail19336.d(20): Error: template instance `Template!()` template `Template` is not defined
        Template!() a(a.x);
        ^
fail_compilation/fail19336.d(20): Error: circular reference to `fail19336.Foo.a`
        Template!() a(a.x);
                    ^
fail_compilation/fail19336.d(23): Error: circular reference to `fail19336.b`
int b(b.x);
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19336

struct Foo
{
        Template!() a(a.x);
}

int b(b.x);
