/*
REQUIRED_ARGS: -transition=checkimports
TEST_OUTPUT:
---
fail_compilation/checkimports2.d(21): Deprecation: local import search method found variable imp1.Y instead of variable imp2.Y
fail_compilation/checkimports2.d(17): Deprecation: class checkimports2.B variable imp2.X found in local import
fail_compilation/checkimports2.d(26): Error: no property 'X' for type 'checkimports2.B'
fail_compilation/checkimports2.d(17): Deprecation: class checkimports2.B variable imp2.Y found in local import
fail_compilation/checkimports2.d(27): Error: no property 'Y' for type 'checkimports2.B'
---
*/

import imports.imp1;

enum X = 0;

class B
{
    import imports.imp2;
    static assert(X == 0);
    int[Y] aa;
}

class C : B
{
    static assert(B.X == 0);
    static assert(B.Y == 2);

    static assert(X == 0);
    static assert(Y == 1);
}
