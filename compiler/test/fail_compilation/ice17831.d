/*
TEST_OUTPUT:
---
fail_compilation/ice17831.d(28): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
fail_compilation/ice17831.d(28): Error: `case` variables have to be `const` or `immutable`
fail_compilation/ice17831.d(28): Error: `case` variable `i` declared at fail_compilation/ice17831.d(26) cannot be declared in `switch` body
fail_compilation/ice17831.d(42): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
fail_compilation/ice17831.d(42): Error: `case` variables have to be `const` or `immutable`
fail_compilation/ice17831.d(42): Error: `case` variable `i` declared at fail_compilation/ice17831.d(40) cannot be declared in `switch` body
fail_compilation/ice17831.d(57): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
fail_compilation/ice17831.d(57): Error: `case` variables have to be `const` or `immutable`
fail_compilation/ice17831.d(57): Error: `case` variable `i` declared at fail_compilation/ice17831.d(54) cannot be declared in `switch` body
fail_compilation/ice17831.d(70): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
fail_compilation/ice17831.d(70): Error: `case` variables have to be `const` or `immutable`
fail_compilation/ice17831.d(70): Error: `case` variable `i` declared at fail_compilation/ice17831.d(69) cannot be declared in `switch` body
fail_compilation/ice17831.d(82): Deprecation: run-time `case` variables are deprecated, use if-else statements instead
fail_compilation/ice17831.d(82): Error: `case` variables have to be `const` or `immutable`
fail_compilation/ice17831.d(82): Error: `case` variable `i` declared at fail_compilation/ice17831.d(81) cannot be declared in `switch` body
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
