// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_overwritten.d(16): Warning: value assigned to `x` is never used
compilable/diag_access_unused_overwritten.d(17):        overwritten here
compilable/diag_access_unused_overwritten.d(18): Warning: unused local constant `y` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_overwritten.d(18): Warning: unused local constant `y` of unittest, remove, rename to `_` or prepend `_` to name to silence
---
*/

unittest
{
    bool x;
    x = false;                  // warn
    x = false;                  // overwritten here
    const y = x;                // warn
}
