/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail17492.d(24): Error: function `fail17492.C.testE()` conflicts with previous declaration at fail_compilation/fail17492.d(17)
    void testE()
         ^
fail_compilation/fail17492.d(41): Error: function `fail17492.S.testE()` conflicts with previous declaration at fail_compilation/fail17492.d(34)
    void testE()
         ^
---
https://issues.dlang.org/show_bug.cgi?id=17492
*/

class C
{
    void testE()
    {
        class I
        {
        }
    }

    void testE()
    {
        class I
        {
        }
    }
}

class S
{
    void testE()
    {
        struct I
        {
        }
    }

    void testE()
    {
        struct I
        {
        }
    }
}
