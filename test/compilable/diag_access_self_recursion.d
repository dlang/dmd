// REQUIRED_ARGS: -wi -unittest -diagnose=access

/*
TEST_OUTPUT:
---
compilable/diag_access_self_recursion.d(28): Warning: unused local variable `x` of unittest, remove, rename to `_` or prepend `_` to name to silence
compilable/diag_access_self_recursion.d(28): Warning: unused public variable `x` of unittest, rename to `_` or prepend `_` to name to silence
compilable/diag_access_self_recursion.d(28): Warning: unmodified public variable `x` of unittest should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_self_recursion.d(28): Warning: unused local variable `x` of unittest, remove, rename to `_` or prepend `_` to name to silence
---
*/

void selfRecursion1() @safe pure nothrow @nogc
{
    selfRecursion1();           // TODO: should error
}

void selfRecursion2() @safe pure nothrow @nogc
{
    if (true)
        return selfRecursion2(); // TODO: should error
    else
        return selfRecursion2(); // TODO: should error
}

unittest
{
    bool x;                     // warn
}
