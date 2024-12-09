// https://issues.dlang.org/show_bug.cgi?id=21091

/*
TEST_OUTPUT:
----
fail_compilation/fail21091a.d(18): Error: unable to read module `Ternary`
    import Ternary;
           ^
fail_compilation/fail21091a.d(18):        Expected 'Ternary.d' or 'Ternary/package.d' in one of the following import paths:
import path[0] = fail_compilation
import path[1] = $p:druntime/import$
import path[2] = $p:phobos$
----
*/

struct NullAllocator
{
    import Ternary;
    Ternary owns() { }
}
