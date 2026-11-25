/*
TEST_OUTPUT:
---
fail_compilation/aliasthis_mod.d(14): Error: mutable method `aliasthis_mod.S.get` is not callable using a `const` object
---
*/

struct T { int x; }
struct S
{
    T get() { return T(); }
    alias get this;
}
alias X = typeof(const(S).x);
