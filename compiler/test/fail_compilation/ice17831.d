/*
TEST_OUTPUT:
---
fail_compilation/ice17831.d(43): Error: `case` variables have to be `const` or `immutable`
            case i:
            ^
fail_compilation/ice17831.d(43): Error: `case` variable `i` declared at fail_compilation/ice17831.d(41) cannot be declared in `switch` body
            case i:
            ^
fail_compilation/ice17831.d(57): Error: `case` variables have to be `const` or `immutable`
            case i:
            ^
fail_compilation/ice17831.d(57): Error: `case` variable `i` declared at fail_compilation/ice17831.d(55) cannot be declared in `switch` body
            case i:
            ^
fail_compilation/ice17831.d(72): Error: `case` variables have to be `const` or `immutable`
            case i:
            ^
fail_compilation/ice17831.d(72): Error: `case` variable `i` declared at fail_compilation/ice17831.d(69) cannot be declared in `switch` body
            case i:
            ^
fail_compilation/ice17831.d(85): Error: `case` variables have to be `const` or `immutable`
        case i:
        ^
fail_compilation/ice17831.d(85): Error: `case` variable `i` declared at fail_compilation/ice17831.d(84) cannot be declared in `switch` body
        case i:
        ^
fail_compilation/ice17831.d(97): Error: `case` variables have to be `const` or `immutable`
        case i:
        ^
fail_compilation/ice17831.d(97): Error: `case` variable `i` declared at fail_compilation/ice17831.d(96) cannot be declared in `switch` body
        case i:
        ^
---
 */

void test17831a()
{
    switch (0)
    {
        foreach (i; 0 .. 5)
        {
            case i:
                break;
        }
        default:
            break;
    }
}

void test17831b()
{
    switch (0)
    {
        for (int i = 0; i < 5; i++)
        {
            case i:
                break;
        }
        default:
            break;
    }
}

void test17831c()
{
    switch (0)
    {
        int i = 0;
        while (i++ < 5)
        {
            case i:
                break;
        }
        default:
            break;
    }
}

void test17831d()
{
    switch (0)
    {
        int i = 0;
        case i:
            break;
        default:
            break;
    }
}

void test17831e()
{
    switch (0)
    {
        static int i = 0;
        case i:
            break;
        default:
            break;
    }
}
