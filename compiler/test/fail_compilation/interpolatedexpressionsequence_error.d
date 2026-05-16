/* TEST_OUTPUT:
REQUIRED_ARGS: -vcolumns
---
fail_compilation/interpolatedexpressionsequence_error.d(12,14): Error: undefined identifier `x`
fail_compilation/interpolatedexpressionsequence_error.d(13,34): Error: undefined identifier `z`
fail_compilation/interpolatedexpressionsequence_error.d(14,22): Error: undefined identifier `y`
fail_compilation/interpolatedexpressionsequence_error.d(15,16): Error: expression expected, not `End of File`
---
*/
// https://github.com/dlang/dmd/issues/23084

auto a = i"$(x)";
auto b = i`before $(1) between $(z) after`;
auto c = iq{before $(y) between $(z) after};
auto d = i"$(x%)";
