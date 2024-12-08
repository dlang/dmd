/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/deprecateopdot.d(33): Error: `opDot` is obsolete. Use `alias this`
    t.a = 4;
    ^
fail_compilation/deprecateopdot.d(34): Error: `opDot` is obsolete. Use `alias this`
    assert(t.a == 4);
           ^
fail_compilation/deprecateopdot.d(35): Error: `opDot` is obsolete. Use `alias this`
    t.b = 5;
    ^
---
*/
struct S6
{
    int a, b;
}
struct T6
{
    S6 s;

    S6* opDot() return
    {
        return &s;
    }
}

void test6()
{
    T6 t;
    t.a = 4;
    assert(t.a == 4);
    t.b = 5;
}
