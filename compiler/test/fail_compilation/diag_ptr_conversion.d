/*
TEST_OUTPUT:
---
dmd/compiler/test/fail_compilation/diag_ptr_conversion.d(5): Error: cannot implicitly convert `const(int)*` to `int*`
dmd/compiler/test/fail_compilation/diag_ptr_conversion.d(5):        Note: Converting const to mutable requires an explicit cast (`cast(int*)`).
dmd/compiler/test/fail_compilation/diag_ptr_conversion.d(6): Error: cannot implicitly convert `int*` to `float*`
dmd/compiler/test/fail_compilation/diag_ptr_conversion.d(6):        Note: Pointer types point to different base types (`int` vs `float`)
---
*/

void testPointerConversions()
{
    int* p;
    const(int)* cp = p;  // Warn: mutable -> const
    p = cp;              // Error: const -> mutable
    float* f = p;        // Error: incompatible types
}
