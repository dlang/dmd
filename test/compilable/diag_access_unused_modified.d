// REQUIRED_ARGS: -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_modified.d(23): Warning: unused local variable `y` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(23): Warning: unused public variable `y` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(23): Warning: unmodified public variable `y` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(28): Warning: unused local variable `x` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(28): Warning: unused public variable `x` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(28): Warning: unmodified public variable `x` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(34): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(33): Warning: unused modified public variable `x` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(23): Warning: unused local variable `y` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_modified.d(28): Warning: unused local variable `x` of unittest, remove, rename to `_` or prepend `_` to name to silence
---
*/

unittest
{
    bool x;
    x = false;
    bool y = x;                // warn
}

unittest
{
    bool x;                     // warn
}

unittest
{
    bool x;                     // warn
    x = true;                   // warn, value set is never used
}
