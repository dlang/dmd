/*
EXTRA_FILES: imports/ice10600a.d imports/ice10600b.d
TEST_OUTPUT:
---
fail_compilation/ice10600.d(123): Error: template instance `to!(int, double)` does not match template declaration `to(T)`
fail_compilation/ice10600.d(123):        instantiated from here: `to!(int, double)`
fail_compilation/imports/ice10600b.d(5):        Candidate match: to(T)
---
*/

#line 100

import imports.ice10600a;
import imports.ice10600b;

template Tuple(Specs...)
{
    struct Tuple
    {
        string toString()
        {
            Appender!string w;  // issue!
            return "";
        }
    }
}
Tuple!T tuple(T...)(T args)
{
    return typeof(return)();
}

void main()
{
    auto a = to!int("");
    auto b = to!(int, double)("");
    tuple(1);
}
