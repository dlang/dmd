/*
TEST_OUTPUT:
---
fail_compilation/switch_fallthrough.d(17): Error: switch case fallthrough - use 'goto default;' if intended
fail_compilation/switch_fallthrough.d(24): Error: switch case fallthrough - use 'goto case;' if intended
---
*/

// no switch fallthrough error with multi-valued case
// https://issues.dlang.org/show_bug.cgi?id=22999
void test22999()
{
    int i;
    switch (0)
    {
        case 0, 1: i = 20;
        default: assert(0);
    }

    switch (0)
    {
        default:
        case 0, 1: i = 20;
        case 2, 3: i = 30;
    }
}

/*
Bugzilla 16967
TEST_OUTPUT:
---
fail_compilation/switch_fallthrough.d(43): Error: switch case fallthrough - use 'goto default;' if intended
fail_compilation/switch_fallthrough.d(53): Error: switch case fallthrough - use 'goto default;' if intended
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

/*
Bugzilla 11653
TEST_OUTPUT:
---
fail_compilation/switch_fallthrough.d(80): Error: switch case fallthrough - use 'goto case;' if intended
fail_compilation/switch_fallthrough.d(85): Error: switch case fallthrough - use 'goto default;' if intended
---
*/

void test11653()
{
    int test = 12412;
    int output = 0;
    switch(test)
    {
        case 1:
            output = 1;
            //break; //Oops..
        case 2: .. case 3:
            output = 2;
            break;
        case 4:
            output = 3;
        default:
            output = 4;
    }
}

/**
Missing switch case fallthrough error when generating cases with static foreach #20242
https://github.com/dlang/dmd/issues/20242

TEST_OUTPUT:
---
fail_compilation/switch_fallthrough.d(108): Error: switch case fallthrough - use 'goto case;' if intended
fail_compilation/switch_fallthrough.d(108): Error: switch case fallthrough - use 'goto case;' if intended
fail_compilation/switch_fallthrough.d(111): Error: switch case fallthrough - use 'goto case;' if intended
---
**/
void test1(int i)
{
    int x;
    switch(i)
    {
        static foreach(j; 0 .. 3)
        {
            case j:
                x = j;
        }
        case 3:
            x = 2;
            break;
        default: break;
    }
}
