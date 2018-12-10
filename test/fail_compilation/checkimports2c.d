// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/checkimports2c.d(25): Error: no property `X` for type `checkimports2c.B`, did you mean non-visible variable `X`?
fail_compilation/checkimports2c.d(25):        while evaluating: `static assert((B).X == 2)`
fail_compilation/checkimports2c.d(26): Error: no property `Y` for type `checkimports2c.B`, did you mean non-visible variable `Y`?
fail_compilation/checkimports2c.d(26):        while evaluating: `static assert((B).Y == 2)`
---
*/

import imports.imp1;

enum X = 0;

class B
{
    import imports.imp2;
    static assert(X == 0);      // .X
    int[Y] aa;                  // imp2.Y
}

class C : B
{
    static assert(B.X == 2);    // imp2.X --> error (not visible from here)
    static assert(B.Y == 2);    // imp2.Y --> error (not visible from here)

    static assert(X == 0);      // .X
    static assert(Y == 1);      // imp1.Y
}
