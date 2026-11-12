/*
TEST_OUTPUT:
---
fail_compilation/attributediagnostic_cycle.d(14): Error: function `attributediagnostic_cycle.a!()` is not `nothrow`
fail_compilation/attributediagnostic_cycle.d(4):        which calls `b`
fail_compilation/attributediagnostic_cycle.d(9):        which calls `a`, completing a cycle in the diagnostic chain
fail_compilation/attributediagnostic_cycle.d(15): Error: function `attributediagnostic_cycle.a!()` is not `nothrow`
fail_compilation/attributediagnostic_cycle.d(4):        which calls `b`
fail_compilation/attributediagnostic_cycle.d(9):        which calls `a`, completing a cycle in the diagnostic chain
fail_compilation/attributediagnostic_cycle.d(12): Error: function `attributediagnostic_cycle.test` may throw but is marked as `nothrow`
---
*/
#line 1
// Stop at the closing link, independently for each diagnostic.
int a()(int n)
{
    return n ? b(n - 1) : 0;
}

int b()(int n)
{
    return n ? a(n - 1) : 0;
}

void test() nothrow
{
    a(3);
    a(4);
}
