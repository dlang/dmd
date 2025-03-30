/* TEST_OUTPUT:
---
fail_compilation/fix22253.c(106): Error: `ptr` is not a member of `char[10]`
fail_compilation/fix22253.c(107): Error: `length` is not a member of `char[10]`
fail_compilation/fix22253.c(108): Error: `dup` is not a member of `char[10]`
fail_compilation/fix22253.c(109): Error: `init` is not a member of `char`
fail_compilation/fix22253.c(113): Error: `tupleof` is not a member of `S`
---
 */
// https://issues.dlang.org/show_bug.cgi?id=22253

#line 100

void foo(int, int);

void test()
{
    char a[10];
    char *p = a.ptr;
    unsigned i = a.length;
    char *q = a.dup.ptr;
    p = p->init;
    struct S { int a, b; };
    struct S s;
    s.a = s.b;
    foo(s.tupleof);
}
