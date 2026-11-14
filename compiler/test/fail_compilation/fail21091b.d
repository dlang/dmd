// https://issues.dlang.org/show_bug.cgi?id=21091

/*
TEST_OUTPUT:
----
fail_compilation/fail21091b.d(15): Error: unable to read module `Tid`
fail_compilation/fail21091b.d(15):        Expected 'Tid.d' or 'Tid/package.d' in one of the following import paths:
import path[0] = fail_compilation
import path[1] = $p:druntime/import$
----
*/

class Logger
{
    import Tid;
    Tid threadId;
}
