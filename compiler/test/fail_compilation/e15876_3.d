/*
TEST_OUTPUT:
---
fail_compilation/e15876_3.d(20): Error: unexpected `(` in declarator
fail_compilation/e15876_3.d(20): Error: basic type expected, not `=`
fail_compilation/e15876_3.d(21): Error: found `End of File` when expecting `(`
fail_compilation/e15876_3.d(21): Error: found `End of File` instead of statement
fail_compilation/e15876_3.d(21): Error: expression expected, not `End of File`
fail_compilation/e15876_3.d(21): Error: found `End of File` when expecting `;` following `for` condition
fail_compilation/e15876_3.d(21): Error: expression expected, not `End of File`
fail_compilation/e15876_3.d(21): Error: found `End of File` when expecting `)`
fail_compilation/e15876_3.d(21): Error: found `End of File` instead of statement
fail_compilation/e15876_3.d(21): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_3.d(20):        unmatched `{`
fail_compilation/e15876_3.d(21): Error: found `End of File` when expecting `)`
fail_compilation/e15876_3.d(21): Error: variable name expected after type `<error type>`, not `End of File`
fail_compilation/e15876_3.d(21): Error: semicolon expected following function declaration, not `End of File`
---
*/
d(={for
