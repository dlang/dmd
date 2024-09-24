// REQUIRED_ARGS: -w

/*
TEST_OUTPUT:
---
fail_compilation/unused_import.d(17): Warning: Import `imports.unused_import` is unused
fail_compilation/unused_import.d(20): Warning: Import `imports.unused_import` is unused
fail_compilation/unused_import.d(21): Warning: Import `imports.unused_import` is unused
fail_compilation/unused_import.d(25): Warning: Import `imports.unused_import` is unused
Error: warnings are treated as errors
       Use -wi if you wish to treat warnings only as informational.
---
*/
void gun()
{
    {
        import imports.unused_import;
    }
    {
        import imports.unused_import;
        import imports.unused_import;
    }
    {
        import imports.unused_import;
        import imports.unused_import;
        int b = a;
    }
    {
        import imports.unused_import;
        auto t = &fun;
    }
    {
        import imports.unused_import;
        int u = a;
    }
    {
        import imports.unused_import;
        int u = t;
    }
    {
        import imports.unused_import;
        int u = h;
    }
    // selective and renamed imports are not checked
    // because that falls under the scope of unused
    // variables check.
    {
        import imports.unused_import : a;
        import imports.unused_import : q = t;

        int b = a;
    }
}
