// REQUIRED_ARGS: -transition=checkimports
/*
TEST_OUTPUT:
---
fail_compilation/checkimports2a.d(24): Deprecation: local import search method found variable imports.imp2.X instead of variable checkimports2a.X
fail_compilation/checkimports2a.d(30): Deprecation: local import search method found variable imports.imp2.X instead of nothing
fail_compilation/checkimports2a.d(30): Error: no property 'X' for type 'checkimports2a.B'
fail_compilation/checkimports2a.d(31): Deprecation: local import search method found variable imports.imp2.Y instead of nothing
fail_compilation/checkimports2a.d(31): Error: no property 'Y' for type 'checkimports2a.B'
fail_compilation/checkimports2a.d(33): Deprecation: local import search method found variable imports.imp2.X instead of variable checkimports2a.X
fail_compilation/checkimports2a.d(34): Deprecation: local import search method found variable imports.imp2.Y instead of variable imports.imp1.Y
---
*/

// new lookup + information

import imports.imp1;

enum X = 0;

class B
{
    import imports.imp2;
    static assert(X == 0);      // imp2.X --> .X
    int[Y] aa;                  // imp2.Y
}

class C : B
{
    static assert(B.X == 0);    // imp2.X --> error
    static assert(B.Y == 2);    // imp2.Y --> error

    static assert(X == 0);      // imp2.X --> .X
    static assert(Y == 1);      // imp2.Y --> imp1.Y
}
