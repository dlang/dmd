// REQUIRED_ARGS: -verrors=simple

/*
TEST_OUTPUT:
---
compilable/enum_union_complex_transition.d(11): Deprecation: use of complex type `cdouble` is deprecated, use `std.complex.Complex!(double)` instead
compilable/enum_union_complex_transition.d(11): Deprecation: use of imaginary type `idouble` is deprecated, use `double` instead
---
*/

enum union Values
{
    case cdouble,
    case idouble;
}
