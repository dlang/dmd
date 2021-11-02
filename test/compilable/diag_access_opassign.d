// REQUIRED_ARGS: -vcolumns -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_opassign.d(29,16): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(30,16): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(33,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(34,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(35,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(36,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/math.d(7454,13): Warning: value assigned to public variable `v` of function is unused, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/math.d(7413,20): Warning: unmodified public variable `p` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(37,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(37,11): Warning: unused modified public variable `x` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(38,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(39,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_opassign.d(40,14): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
---
*/

unittest
{
    // `PostExp`
    { int x; x++; }             // TODO: warn
    { int x; x--; }             // TODO: warn

    // `PreExp`
    { int x; ++x; }             // warn
    { int x; --x; }             // warn

    // `BinAssignExp`
    { int x; x += 1; }          // warn
    { int x; x -= 1; }          // warn
    { int x; x *= 1; }          // warn
    { int x; x /= 1; }          // warn
    { int x; x ^^= 1; }         // warn
    { int x; x ^= 1; }          // warn
    { int x; x |= 1; }          // warn
    { int x; x &= 1; }          // warn
}
