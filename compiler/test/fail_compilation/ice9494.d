/*
TEST_OUTPUT:
---
fail_compilation/ice9494.d(14): Error: circular reference to variable `ice9494.test`
fail_compilation/ice9494.d(18): Deprecation: `this` is only defined in non-static member functions, not inside scope `Foo`
fail_compilation/ice9494.d(18):        Use `typeof(this)` or `Foo.test`
fail_compilation/ice9494.d(18): Error: circular reference to variable `ice9494.Foo.test`
fail_compilation/ice9494.d(23): Deprecation: `this` is only defined in non-static member functions, not inside scope `Bar`
fail_compilation/ice9494.d(23):        Use `typeof(this)` or `Bar.test`
fail_compilation/ice9494.d(23): Error: circular reference to variable `ice9494.Bar.test`
---
*/

int[test] test;  // stack overflow

class Foo
{
    int[this.test] test;  // stack overflow
}

struct Bar
{
    int[this.test] test;  // stack overflow
}
