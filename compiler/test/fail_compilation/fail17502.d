/*
TEST_OUTPUT:
---
fail_compilation/fail17502.d(21): Error: function `fail17502.Foo.foo` `void` functions have no result
    out (res) { assert(res > 5); }
              ^
fail_compilation/fail17502.d(21): Error: undefined identifier `res`
    out (res) { assert(res > 5); }
                       ^
fail_compilation/fail17502.d(25): Error: function `fail17502.Foo.bar` `void` functions have no result
    out (res) { assert (res > 5); }
              ^
fail_compilation/fail17502.d(25): Error: undefined identifier `res`
    out (res) { assert (res > 5); }
                        ^
---
*/
class Foo
{
    void foo()
    out (res) { assert(res > 5); }
    do {}

    auto bar()
    out (res) { assert (res > 5); }
    do { return; }
}
