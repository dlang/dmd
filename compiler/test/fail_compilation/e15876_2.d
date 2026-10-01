/*
TEST_OUTPUT:
---
fail_compilation/e15876_2.d(12): Error: identifier expected following `template`
fail_compilation/e15876_2.d(12): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_2.d(11):        unmatched `{`
fail_compilation/e15876_2.d(12): Error: found `End of File` when expecting `]`
fail_compilation/e15876_2.d(12): Error: variable name expected after type `<error type>`, not `End of File`
---
*/
o[{template
