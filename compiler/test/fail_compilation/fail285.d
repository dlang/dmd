/*
TEST_OUTPUT:
---
fail_compilation/fail285.d(21): Error: with symbol `fail285.S.x` is shadowing local symbol `fail285.main.x`
        x++;
        ^
---
*/

struct S
{
    int x;
}

void main()
{
    int x;
    S s;
    with (s)
    {
        x++;
    }
}
