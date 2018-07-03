/*
https://issues.dlang.org/show_bug.cgi?id=18385
Disabled for 2.079, s.t. a deprecation cycle can be started with 2.080
DISABLED: win32 win64 osx linux freebsd dragonflybsd
TEST_OUTPUT:
---
fail_compilation/fail17492.d(20): Error: class `fail17492.C.testE.I` already exists at fail17492.d(13). Perhaps in another function with the same name?
fail_compilation/fail17492.d(37): Error: struct `fail17492.S.testE.I` already exists at fail17492.d(30). Perhaps in another function with the same name?
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
