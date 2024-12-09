/*
TEST_OUTPUT:
---
fail_compilation/ice10713.d(15): Error: no property `nonExistingField` for type `ice10713.S`
    void f(typeof(this.nonExistingField) a) {}
                  ^
fail_compilation/ice10713.d(13):        struct `S` defined here
struct S
^
---
*/

struct S
{
    void f(typeof(this.nonExistingField) a) {}
}
