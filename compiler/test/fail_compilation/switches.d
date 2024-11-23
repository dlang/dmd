/*
TEST_OUTPUT:
---
fail_compilation/switches.d(18): Error: `case 2` not found
            goto case 2;
            ^
fail_compilation/switches.d(29): Error: no `case` statement following `goto case;`
            goto case;
            ^
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
}
