/* TEST_OUTPUT:
---
fail_compilation/test22759.c(108): Error: cannot modify `const` expression `*p`
fail_compilation/test22759.c(111): Error: cannot modify `const` expression `r`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22759

#line 100

void test()
{
    int *const q;
    *q = 3;
    q = 0;

    const int *p;
    *p = 3;                 // 108

    const int *const r;
    r = 0;                  // 111
}
