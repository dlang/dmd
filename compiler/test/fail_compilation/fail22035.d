// https://issues.dlang.org/show_bug.cgi?id=22035
/* TEST_OUTPUT:
---
fail_compilation/fail22035.d(12): Error: found `2` when expecting `:`
    case 1 2:
           ^
fail_compilation/fail22035.d(12): Error: found `:` instead of statement
---
*/
int test22035()
{
    case 1 2:
}
