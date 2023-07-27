/*
TEST_OUTPUT:
---
fail_compilation/ice10713.d(12): Deprecation: `this` is only defined in non-static member functions, not inside scope `S`
fail_compilation/ice10713.d(12):        Use `typeof(this)` or `S.nonExistingField`
fail_compilation/ice10713.d(12): Error: no property `nonExistingField` for type `ice10713.S`
---
*/

struct S
{
    void f(typeof(this.nonExistingField) a) {}
}
