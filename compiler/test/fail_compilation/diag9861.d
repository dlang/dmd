/*
TEST_OUTPUT:
---
fail_compilation/diag9861.d(12): Error: no property `epsilon` for type `int`
struct Foo(T, real x = T.epsilon) {}
                       ^
fail_compilation/diag9861.d(13):        while looking for match for `Foo!int`
Foo!(int) q;
^
---
*/
struct Foo(T, real x = T.epsilon) {}
Foo!(int) q;
