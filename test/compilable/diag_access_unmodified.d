// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_unmodified.d(37): Warning: value assigned to public variable `f` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(36): Warning: unused modified public variable `f` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(44): Warning: value assigned to public variable `y` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(43): Warning: unused modified public variable `y` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(51): Warning: value assigned to public variable `y` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(50): Warning: unused modified public variable `y` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(58): Warning: value assigned to public variable `y` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(57): Warning: unused modified public variable `y` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(63): Warning: unmodified public variable `f` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(69): Warning: unmodified public variable `x` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(71): Warning: value assigned to public variable `y` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(70): Warning: unused modified public variable `y` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(78): Warning: variable `y` already `null`
compilable/diag_access_unmodified.d(78): Warning: value assigned to public variable `y` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(77): Warning: unused modified public variable `y` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(85): Warning: variable `y` already `null`
compilable/diag_access_unmodified.d(85): Warning: value assigned to public variable `y` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unmodified.d(84): Warning: unused modified public variable `y` of unittest, rename to `_` or prepend `_` to name to silence
---
*/

unittest
{
    int f;                      // no warn, because written below
    f = 42;                     // written
    assert(f is 42);            // read
}

unittest
{
    int f;                      // warn because written to but never used
    f = 42;                     // warn
}

unittest
{
    const x = 0;                // no warn, because already `const`
    int y = x;                  // warn
    y = 1;                      // warn
}

unittest
{
    immutable x = 0;            // no warn, because already `immutable`
    int y = x;                  // warn
    y = 1;                      // warn
}

unittest
{
    enum x = 0;                 // no warn, because manifest constant
    int y = x;                  // warn
    y = 1;                      // warn
}

unittest
{
    Object f;                   // warn
    assert(f is null);
}

unittest
{
    int x = 0;                  // warn
    int y = x;                  // warn
    y = 1;                      // warn
}

unittest
{
    int* x = null;              // warn
    int* y = x;                 // warn
    y = null;                   // warn
}

unittest
{
    Object x = null;            // warn
    Object y = x;               // warn
    y = null;                   // warn
}
