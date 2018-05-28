/*
REQUIRED_ARGS: -D
TEST_OUTPUT:
---
fail_compilation/fail18721.d(12): Error: `static foreach` can't be lowered.
---
*/
// https://issues.dlang.org/show_bug.cgi?id=18721
///
template allSameType()
{
    static foreach (idx; T)
            enum allSameType = 1;
}
