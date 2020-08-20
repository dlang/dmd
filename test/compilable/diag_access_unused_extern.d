// REQUIRED_ARGS: -wi -vcolumns -unittest -diagnose=access

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_extern.d(18,13): Warning: unused private variable `x1` of module `diag_access_unused_extern`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_extern.d(19,20): Warning: unused private variable `x2` of module `diag_access_unused_extern`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_extern.d(20,13): Warning: unused private variable `x3` of module `diag_access_unused_extern`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_extern.d(21,23): Warning: unused private variable `x4` of module `diag_access_unused_extern`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_extern.d(23,9): Warning: unused private struct `S`
compilable/diag_access_unused_extern.d(25,19): Warning: unused private struct `DS`
compilable/diag_access_unused_extern.d(26,19): Warning: unused private struct `CS`
compilable/diag_access_unused_extern.d(35,9): Warning: unused private class `C`
---
*/

public int x0;
private int x1;                 // unused
extern private int x2;          // TODO: may be used externally
private int x3;                 // unused
extern(C) private int x4;       // TODO: may be used externally

private struct S {}             // unused
extern private struct ES {}     // may be used externally
extern(D) private struct DS {}  // TODO: may be used externally
extern(C) private struct CS {}  // TODO: may be used externally
extern(C++) private struct CxxS
{
    public void foo() {}        // TODO: may be used externally
    private void goo() {}       // TODO: may be used externally
    public int y;               // TODO: may be used externally
    private int x;              // TODO: may be used externally
}

private class C {}              // unused
extern private class EC {}      // may be used externally
