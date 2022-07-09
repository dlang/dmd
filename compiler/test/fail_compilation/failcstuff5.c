// check semantic analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff5.c(404): Error: undefined identifier `p1`
fail_compilation/failcstuff5.c(404): Error: undefined identifier `p2`
fail_compilation/failcstuff5.c(458): Error: cannot take address of bit-field `field`
---
*/

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22584
#line 400
long test22584(long p1, long p2);

long test22584(long, long)
{
    return p1 + p2;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22749
#line 450
struct S22749
{
    int field : 1;
};

void test22749(void)
{
    struct S22749 s;
    void *ptr = &s.field;
}
