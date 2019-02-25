// REQUIRED_ARGS: -transition=checkimports -revert=import
/*
TEST_OUTPUT:
---
fail_compilation/checkimports1c.d(16): Deprecation: local import search method found struct `imports.diag12598a.lines` instead of variable `checkimports1c.C.lines`
fail_compilation/checkimports1c.d(16): Error: `lines` is a `struct` definition and cannot be modified
---
*/

// old lookup + information (the order of switches is reverse)
class C
{
    void f()
    {
        import imports.diag12598a;
        lines ~= "";
    }

    string[] lines;
}
