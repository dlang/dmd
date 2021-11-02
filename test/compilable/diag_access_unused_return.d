// REQUIRED_ARGS: -wi -unittest -vunused -debug

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_return.d(34): Warning: returned expression is always `null`
compilable/diag_access_unused_return.d(39): Warning: unmodified public variable `x` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_return.d(47): Warning: value assigned to public parameter `x` of function is unused, rename to `_` or prepend `_` to name to silence
---
*/

string f0()
{
    string x;
    x ~= "a";
    x ~= "a";
    return x;
}

const(int) f1(int x)            // warn about making `x` const
{
    return x;
}

const(int) f2(int x)            // should warn about making `x` const
{
    const y = x;
    return y;
}

string g()
{
    string x;                   // warn, should be declared const
    return x;                   // warn, always `x` null
}

void h1()
{
    int x;
    if (x)
        x = 42;                 // warn, value assigned is never used
}

void h2(int x)
{
    if (x)
        x = 42;                 // warn, value assigned is never used
}
