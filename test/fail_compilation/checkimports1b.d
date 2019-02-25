// REQUIRED_ARGS: -revert=import -transition=checkimports
/*
TEST_OUTPUT:
---
fail_compilation/checkimports1b.d(16): Deprecation: local import search method found struct `imports.diag12598a.lines` instead of variable `checkimports1b.C.lines`
fail_compilation/checkimports1b.d(16): Error: `lines` is a `struct` definition and cannot be modified
---
*/

// old lookup + information
class C
{
    void f()
    {
        import imports.diag12598a;
        lines ~= "";
    }

    string[] lines;
}
