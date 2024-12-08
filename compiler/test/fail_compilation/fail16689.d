/*
TEST_OUTPUT:
---
fail_compilation/fail16689.d(15): Error: static assert:  "false"
    static assert(false, "false");
    ^
fail_compilation/fail16689.d(18):        instantiated from here: `Issue16689!()`
mixin Issue16689!();
^
---
*/
// Line 1 starts here
mixin template Issue16689()
{
    static assert(false, "false");
}

mixin Issue16689!();
