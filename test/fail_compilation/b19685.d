/* TEST_OUTPUT:
---
fail_compilation/b19685.d(7): Error: overlapping default initialization for field `b` and `a`
fail_compilation/b19685.d(7): Error: overlapping default initialization for field `a` and `b`
---
*/
struct S
{
    union
    {
        struct { int a = 123; }
        struct { int b = 456; }
    }
}

void main()
{
    S s;
    assert(s.b == 123);
}
