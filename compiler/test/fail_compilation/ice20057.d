/*
EXTRA_FILES: imports/i20057.d
TEST_OUTPUT:
---
fail_compilation/ice20057.d(12): Error: alias `ice20057.BlackHole` conflicts with struct `ice20057.BlackHole(alias T)` at fail_compilation/ice20057.d(11)
import imports.i20057: BlackHole;
       ^
---
*/

struct BlackHole(alias T){T t;}
import imports.i20057: BlackHole;

extern(C++) interface Inter
{
    void func();
}

BlackHole!Inter var;
