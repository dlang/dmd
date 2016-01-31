/*
TEST_OUTPUT:
---
fail_compilation/fail15550.d(25): Error: expression (foo!int) has no type
fail_compilation/fail15550.d(26): Error: expression (opDispatch!"_isMatrix") has no type
fail_compilation/fail15550.d(27): Error: expression (baz!"_isMatrix") has no type
---
*/

T foo(T, T2)(T2)
{
}

struct Vector
{
    void opDispatch(string, U)(U)
    {
    }

    void baz(string, U)(U)
    {
    }
}

alias T1 = typeof(foo!int);
alias T2 = typeof(Vector._isMatrix);
alias T3 = typeof(Vector.baz!"_isMatrix");
