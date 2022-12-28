// REQUIRED_ARGS: -w
/*
TEST_OUTPUT:
---
fail_compilation/fail23001.d(20): Warning: statement is not reachable
fail_compilation/fail23001.d(35): Warning: statement is not reachable
fail_compilation/fail23001.d(50): Warning: statement is not reachable
fail_compilation/fail23001.d(110): Warning: statement is not reachable
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/

void test23001a()
{
    switch (0)
    {
        default:
            break;
        switch (1)  // Unreachable
        {
            default:
                break;
        }
    }
}

void test23001b()
{
    switch (0)
    {
        default:
            break;
        { }         // Ignored
        switch (1)  // Unreachable
        {
            default:
                break;
        }
    }
}

void test23001c()
{
    switch (0)
    {
        default:
            break;
        import object;  // Ignored
        switch (1)      // Unreachable
        {
            default:
                break;
        }
    }
}

void test23001d()
{
    switch (0)
    {
        default:
            break;
        label:
            switch (1)  // May be reachable
            {
                default:
                    break;
            }
    }
}

void test23001e()
{
    switch (0)
    {
        default:
            break;
        case 1:
            switch (1)  // May be reachable
            {
                default:
                    break;
            }
    }
}

void test23001f()
{
    switch (0)
    {
        case 0:
            break;
        default:
            switch (1)  // May be reachable
            {
                default:
                    break;
            }
    }
}

void test23001g()
{
    switch (0)
    {
        default:
            break;
        asm {}      // Ignored
        switch (1)  // Unreachable
        {
            default:
                break;
        }
    }
}

void test23001h()
{
    version (DigitalMars)
    {
        switch (0)
        {
            default:
                break;
            asm {nop;}
            switch (1)  // May be reachable
            {
                default:
                    break;
            }
        }
    }
}

void test23001i()
{
    switch (0)
    {
        switch (1)  // ??? May be reachable
        {
            default:
                break;
        }
        default:
            break;
    }
}
