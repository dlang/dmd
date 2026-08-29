/*
TEST_OUTPUT:
---
fail_compilation/e15876_4.d(18): Error: found `)` when expecting `(`
fail_compilation/e15876_4.d(19): Error: found `End of File` when expecting `(`
fail_compilation/e15876_4.d(19): Error: found `End of File` instead of statement
fail_compilation/e15876_4.d(19): Error: expression expected, not `End of File`
fail_compilation/e15876_4.d(19): Error: found `End of File` when expecting `;` following `for` condition
fail_compilation/e15876_4.d(19): Error: expression expected, not `End of File`
fail_compilation/e15876_4.d(19): Error: found `End of File` when expecting `)`
fail_compilation/e15876_4.d(19): Error: found `End of File` instead of statement
fail_compilation/e15876_4.d(19): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_4.d(18):        unmatched `{`
fail_compilation/e15876_4.d(19): Error: found `End of File` when expecting `)`
fail_compilation/e15876_4.d(19): Error: variable name expected after type `<error type>`, not `End of File`
---
*/
typeof){for
