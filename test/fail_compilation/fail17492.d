/*
https://issues.dlang.org/show_bug.cgi?id=18385
Disabled for 2.079, s.t. a deprecation cycle can be started with 2.080
DISABLED: win32 win64 osx linux freebsd dragonflybsd
TEST_OUTPUT:
---
fail_compilation/fail17492.d(17): Error: function `fail17492.C.testE()` conflicts with previous declaration at fail_compilation/fail17492.d(10)
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
