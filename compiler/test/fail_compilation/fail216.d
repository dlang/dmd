/*
TEST_OUTPUT:
---
fail_compilation/fail216.d(22): Error: expression `foo()` is `void` and has no value
    int x = foo();
               ^
fail_compilation/fail216.d(20): Error: function `fail216.bar` has no `return` statement, but is expected to return a value of type `int`
int bar()
    ^
fail_compilation/fail216.d(25):        called from here: `bar()`
const y = bar();
             ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1744
// CTFE: crash on assigning void-returning function to variable
void foo() {}

int bar()
{
    int x = foo();
}

const y = bar();
