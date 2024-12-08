/*
TEST_OUTPUT:
---
fail_compilation/fail259.d(13): Error: function `fail259.C.foo` does not override any function
        override void foo(){}
                      ^
---
*/

class C
{
    final
        override void foo(){}
}
