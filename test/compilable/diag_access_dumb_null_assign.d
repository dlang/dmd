// REQUIRED_ARGS: -wi -unittest -diagnose=access -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_dumb_null_assign.d(32): Warning: variable `x` already `null`
compilable/diag_access_dumb_null_assign.d(39): Warning: variable `x` already `null`
compilable/diag_access_dumb_null_assign.d(39): Warning: value assigned to public variable `x` of unittest is unused, rename to `_` or prepend `_` to name to silence
compilable/diag_access_dumb_null_assign.d(38): Warning: unused modified public variable `x` of unittest, rename to `_` or prepend `_` to name to silence
---
*/

class C
{
    this(int x)
    {
        this.x = x;
    }
    int x;
}

unittest
{
    auto x = new C(42);
    x = null;
    assert(x is null);
}

unittest
{
    Object x;
    x = null;                   // warn
    assert(x is null);
}

unittest
{
    Object x;
    x = null;                   // warn
}
