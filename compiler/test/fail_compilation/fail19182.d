// REQUIRED_ARGS: -c
/*
TEST_OUTPUT:
---
gigi
fail_compilation/fail19182.d(14): Error: `pragma(msg)` is missing a terminating `;`
    pragma(msg, "gigi") // Here
    ^
---
*/

void foo()
{
    pragma(msg, "gigi") // Here
    static foreach (e; [])
    {
        pragma(msg, "lili");
    }

}
