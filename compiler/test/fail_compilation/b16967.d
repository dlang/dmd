/*
 * TEST_OUTPUT:
---
fail_compilation/b16967.d(19): Error: switch case fallthrough - use 'goto default;' if intended
        default:
        ^
fail_compilation/b16967.d(29): Error: switch case fallthrough - use 'goto default;' if intended
        default:
        ^
---
*/
int foo(int x)
in
{
    switch (x)
    {
        case 1:
            assert(x != 0);
        default:
            break;
    }
}
out(v)
{
    switch(v)
    {
        case 42:
            assert(x != 0);
        default:
            break;
    }
}
do
{
    return 42;
}
