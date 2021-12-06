// https://issues.dlang.org/show_bug.cgi?id=22534

struct S { int x; };

void test(struct S *const p)
{
    p->x = 1;
}
