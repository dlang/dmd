/*
TEST_OUTPUT:
---
fail_compilation/diag12280.d(21): Error: undefined identifier `nonexistent`
        nonexistent();
        ^
fail_compilation/diag12280.d(19): Error: template instance `diag12280.f!10` error instantiating
        f!(i + 1);
        ^
fail_compilation/diag12280.d(24):        11 recursive instantiations from here: `f!0`
alias f0 = f!0;
           ^
---
*/

void f(int i)()
{
    static if (i < 10)
        f!(i + 1);
    else
        nonexistent();
}

alias f0 = f!0;
