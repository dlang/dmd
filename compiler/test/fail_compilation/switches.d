/*
TEST_OUTPUT:
---
fail_compilation/switches.d(15): Error: `case 2` not found
fail_compilation/switches.d(26): Error: no `case` statement following `goto case;`
fail_compilation/switches.d(33): Error: case expression `i` cannot be read at compile time
---
*/

void test1(int i)
{
    switch (i)
    {
        case 1:
            goto case 2;
        defaut:
            break;
    }
}

void test2(int i)
{
    switch (i)
    {
        case 1:
            goto case;
        defaut:
            break;
    }
    switch (i)
    {
        case 0:
            goto case i;
        default:
            break;
    }
}
