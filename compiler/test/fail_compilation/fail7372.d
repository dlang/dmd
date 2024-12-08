/*
TEST_OUTPUT:
---
fail_compilation/imports/fail7372.d(7): Error: undefined identifier `X`
        int foo = X;
                  ^
fail_compilation/fail7372.d(16):        parent scope from here: `mixin Issue7372!()`
    mixin Issue7372!();
    ^
---
*/
// Line 1 starts here
import imports.fail7372;
interface I {}
class C : I {
    mixin Issue7372!();
}
