/*
TEST_OUTPUT:
---
fail_compilation/e15876_5.d(13): Error: basic type expected, not `End of File`
fail_compilation/e15876_5.d(13): Error: semicolon expected to close `alias` declaration, not `End of File`
fail_compilation/e15876_5.d(13): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_5.d(12):        unmatched `{`
fail_compilation/e15876_5.d(13): Error: found `End of File` when expecting `]`
fail_compilation/e15876_5.d(13): Error: variable name expected after type `<error type>`, not `End of File`
---
*/
p[{alias
