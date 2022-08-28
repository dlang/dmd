/* https://issues.dlang.org/show_bug.cgi?id=23054 */

struct S { int x; };
struct S* s = &(struct S){1};
int test1(int i)
{
        struct S *b = &(struct S){i};
        return b->x + 1;
}

int test2(int x)
{
        struct S *s = &(struct S){0};
        s->x = x;
        if (x != 0)
        {
                test2(0);
                if (s->x != x) return 2;
        }
        return 0;
}

_Static_assert(test1(1) == 2, "1");
_Static_assert(test2(1) == 0, "2");
