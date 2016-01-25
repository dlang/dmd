/*
TEST_OUTPUT:
---
fail_compilation/fail15550.d(25): Error: template instance foo!int does not match template declaration foo(T, T2)(T2)
fail_compilation/fail15550.d(26): Error: template instance opDispatch!"_isMatrix" does not match template declaration opDispatch(string, U)(U)
fail_compilation/fail15550.d(27): Error: template instance baz!"_isMatrix" does not match template declaration baz(string, U)(U)
---
*/

T foo(T, T2)(T2)
{
}

struct Vector(T, int N)
{
    void opDispatch(string, U)(U)
    {
    }

    void baz(string, U)(U)
    {
    }
}

alias T1 = typeof(foo!int);
alias T2 = typeof(Vector!(int, 2)._isMatrix);
alias T3 = typeof(Vector!(int, 2).baz!"_isMatrix");
