/*
TEST_OUTPUT:
---
fail_compilation/fail11332.d(11): Error: cannot evaluate unimplemented builtin yl2x at compile time
---
*/

void test11332()
{
    import core.math : yl2x;
    static x = yl2x(0, 0);
    // This tests that a un-implemented builtin correctly produces an error.
    // Replace with a different builtin if you have just implemented support for yl2x.
}
