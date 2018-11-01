/*
TEST_OUTPUT:
---
fail_compilation/fail19336.d(14): Error: template instance `Template!()` template `Template` is not defined
fail_compilation/fail19336.d(14): Error: recursive type
fail_compilation/fail19336.d(17): Error: recursive type
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19336

struct Foo
{
        Template!() a(a.x);
}

int b(b.x);
