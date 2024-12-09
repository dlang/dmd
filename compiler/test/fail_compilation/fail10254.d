/*
TEST_OUTPUT:
---
fail_compilation/fail10254.d(32): Error: `pure` function `fail10254.foo` cannot call impure constructor `fail10254.C.this`
    auto c = new C; // This line should be a compilation error.
             ^
fail_compilation/fail10254.d(32): Error: `@safe` function `fail10254.foo` cannot call `@system` constructor `fail10254.C.this`
    auto c = new C; // This line should be a compilation error.
             ^
fail_compilation/fail10254.d(27):        `fail10254.C.this` is declared here
class C { this() { a = 2; } }
          ^
fail_compilation/fail10254.d(33): Error: `pure` function `fail10254.foo` cannot call impure constructor `fail10254.S.this`
    auto s = new S(1);
             ^
fail_compilation/fail10254.d(33): Error: `@safe` function `fail10254.foo` cannot call `@system` constructor `fail10254.S.this`
    auto s = new S(1);
             ^
fail_compilation/fail10254.d(28):        `fail10254.S.this` is declared here
struct S { this(int) { a = 2; } }
           ^
---
*/

int a;

class C { this() { a = 2; } }
struct S { this(int) { a = 2; } }

void foo() pure @safe
{
    auto c = new C; // This line should be a compilation error.
    auto s = new S(1);
}
