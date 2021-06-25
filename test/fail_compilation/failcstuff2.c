// check semantic analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff2.c(54): Error: `& var` has no effect
fail_compilation/failcstuff2.c(55): Error: `*ptr` has no effect
fail_compilation/failcstuff2.c(56): Error: `var` has no effect
fail_compilation/failcstuff2.c(57): Error: `-var` has no effect
fail_compilation/failcstuff2.c(58): Error: `~var` has no effect
fail_compilation/failcstuff2.c(59): Error: `!var` has no effect
---
*/

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22069
#line 50
void test22069()
{
    int var;
    int *ptr;
    &var;
    *ptr;
    +var;
    -var;
    ~var;
    !var;
}
