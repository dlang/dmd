/*
TEST_OUTPUT:
---
fail_compilation/bug4283.d(12): Error: Declaration expected, not '}'
---
*/

template Foo(bool b) {
    static if (b)
        enum bool Foo = 1;
    else
}
