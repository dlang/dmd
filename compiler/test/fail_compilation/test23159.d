// https://issues.dlang.org/show_bug.cgi?id=23159

// REQUIRED_ARGS: -betterC
/*
TEST_OUTPUT:
---
fail_compilation/test23159.d(18): Error: `scope(failure)` cannot be used with -betterC
    scope(failure)
    ^
fail_compilation/test23159.d(22): Error: `scope(success)` cannot be used with -betterC
    scope(success)
    ^
---
*/

void main()
{
    scope(failure)
    {
        int a;
    }
    scope(success)
    {
        int a;
    }
}
