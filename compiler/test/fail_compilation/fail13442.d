// https://issues.dlang.org/show_bug.cgi?id=13442
/* TEST_OUTPUT:
---
fail_compilation/fail13442.d(15): Error: `@safe` function `main` cannot access `__gshared` data `var`
---
*/
__gshared int var;

void f(int i = var) @safe
{
}

void main() @safe
{
    f();
}
