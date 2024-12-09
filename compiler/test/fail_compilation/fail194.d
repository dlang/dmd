/*
TEST_OUTPUT:
---
fail_compilation/fail194.d(20): Error: function `& foo` is overloaded
    bar(1, &foo);
           ^
---
*/

import core.vararg;

void bar(int i, ...) { }

void foo() { }
void foo(int) { }

void main()
{
    //bar(1, cast(void function())&foo);
    bar(1, &foo);
}
