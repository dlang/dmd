/*
TEST_OUTPUT:
---
fail_compilation/attributediagnostic_depth.d(12): Error: function `attributediagnostic_depth.chain!3` is not `nothrow`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(7):        and `object.Exception` being thrown but not caught makes it fail to infer `nothrow`
fail_compilation/attributediagnostic_depth.d(10): Error: function `attributediagnostic_depth.shortChain` may throw but is marked as `nothrow`
fail_compilation/attributediagnostic_depth.d(17): Error: function `attributediagnostic_depth.chain!12` is not `nothrow`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(5):        which calls `chain`
fail_compilation/attributediagnostic_depth.d(15): Error: function `attributediagnostic_depth.longChain` may throw but is marked as `nothrow`
---
*/
#line 1
// Distinct instances with the same displayed name do not form a cycle.
int chain(int depth)()
{
    static if (depth > 0)
        return chain!(depth - 1)();
    else
        throw new Exception("end of chain");
}

void shortChain() nothrow
{
    chain!3(); // Reach the concrete cause.
}

void longChain() nothrow
{
    chain!12(); // Stop after ten links, before the concrete cause.
}
