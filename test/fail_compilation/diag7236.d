/*
TEST_OUTPUT:
---
fail_compilation/diag7236.d(20): Error: class imports.diag7236a.C1 member pm is not accessible
fail_compilation/diag7236.d(21): Error: class imports.diag7236a.C1 member pf is not accessible
fail_compilation/diag7236.d(26): Error: class imports.diag7236a.C1 member pm is not accessible
fail_compilation/diag7236.d(27): Error: class imports.diag7236a.C1 member pf is not accessible
---
*/
import imports.diag7236a;

class C2 : C1
{
}

class NC1
{
    void m(C1 c1)
    {
        c1.pm();   // ng
        c1.pf = 1; // ng
    }

    static void sm(C1 c1)
    {
        c1.pm();   // ng
        c1.pf = 1; // ng
    }
}
