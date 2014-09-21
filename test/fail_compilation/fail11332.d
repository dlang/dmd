/*
TEST_OUTPUT:
---
fail_compilation/fail11332.d(11): Error: cannot evaluate unimplemented builtin rndtol at compile time
---
*/

void test11332()
{
    import std.math : rndtol;
    static x = rndtol(1.2);
    // This tests that a un-implemented builtin correctly produces an error.
    // Replace with a different builtin if you have just implemented support for rndtol.
}
