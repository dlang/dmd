/* TEST_OUTPUT:
---
fail_compilation/fail17492.d(17): Error: function fail17492.C.testE () conflicts with previous declaration at fail_compilation/fail17492.d(10)
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
