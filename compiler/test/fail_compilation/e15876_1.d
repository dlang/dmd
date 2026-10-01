/*
TEST_OUTPUT:
---
fail_compilation/e15876_1.d(13): Error: valid scope identifiers are `exit`, `failure`, or `success`, not `x`
fail_compilation/e15876_1.d(14): Error: found `End of File` when expecting `)`
fail_compilation/e15876_1.d(14): Error: found `End of File` instead of statement
fail_compilation/e15876_1.d(14): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_1.d(13):        unmatched `{`
fail_compilation/e15876_1.d(14): Error: found `End of File` when expecting `]`
fail_compilation/e15876_1.d(14): Error: variable name expected after type `<error type>`, not `End of File`
---
*/
o[{scope(x
