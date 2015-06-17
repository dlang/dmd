/*
REQUIRED_ARGS: -inline
TEST_OUTPUT:
---
fail_compilation/pragmainline2.d(12): Error: function pragmainline2.foo cannot inline function
---
*/

pragma(inline, true):
pragma(inline, false):
pragma(inline)
void foo()
{
    pragma(inline, false);
    pragma(inline);
    pragma(inline, true);
    while (0) { }
}

void main()
{
    foo();
}

