// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_scopes.d(12): Warning: unmodified public variable `x` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
---
*/

int f1()
{
    int x;
    if (x)
    {
        x = 42;
    }
    return x;
}
