/*
TEST_OUTPUT:
---
fail_compilation/ice9494.d(16): Error: circular reference to variable `ice9494.test`
int[test] test;  // stack overflow
          ^
fail_compilation/ice9494.d(20): Error: circular reference to variable `ice9494.Foo.test`
    int[this.test] test;  // stack overflow
        ^
fail_compilation/ice9494.d(25): Error: circular reference to variable `ice9494.Bar.test`
    int[this.test] test;  // stack overflow
        ^
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
