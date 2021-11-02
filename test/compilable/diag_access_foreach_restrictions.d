// REQUIRED_ARGS: -wi -vcolumns -unittest -vunused
// SPEC: https://dlang.org/spec/statement.html#foreach_restrictions

/*
TEST_OUTPUT:
---
compilable/diag_access_foreach_restrictions.d(29,9): Warning: variable `a` already `null`
compilable/diag_access_foreach_restrictions.d(28,9): Warning: value assigned to `a` is never used
compilable/diag_access_foreach_restrictions.d(29,9):        overwritten here
/home/per/Work/dmd/test/../../druntime/import/core/internal/array/capacity.d(44,18): Warning: unmodified public variable `ti` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_foreach_restrictions.d(24,11): Warning: unused public variable `a` of function, rename to `_` or prepend `_` to name to silence
compilable/diag_access_foreach_restrictions.d(24,11): Warning: unmodified public variable `a` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/array/utils.d(18,10): Warning: unused public variable `impureBypass` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/array/utils.d(18,10): Warning: unmodified public variable `impureBypass` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/array/utils.d(77,19): Warning: unmodified public variable `size` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/array/utils.d(57,16): Warning: unmodified public variable `name` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/array/utils.d(73,15): Warning: unused public variable `currentlyAllocated` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/array/utils.d(73,15): Warning: unmodified public variable `currentlyAllocated` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

void fun() @safe pure
{
    int[] a;                    // TODO: no warn
    int[] b;
    foreach (_; a)
    {
        a = null;               // warn. TODO: error
        a = b;                  // warn. TODO: error
        a.length += 10;         // TODO: error
    }
}
