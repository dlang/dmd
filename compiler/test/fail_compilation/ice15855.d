// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/ice15855.d(20): Error: found `End of File` when expecting `(`
fail_compilation/ice15855.d(20): Error: found `End of File` instead of statement
fail_compilation/ice15855.d(20): Error: expression expected, not `End of File`
fail_compilation/ice15855.d(20): Error: found `End of File` when expecting `;` following `for` condition
fail_compilation/ice15855.d(20): Error: expression expected, not `End of File`
fail_compilation/ice15855.d(20): Error: found `End of File` when expecting `)`
fail_compilation/ice15855.d(20): Error: found `End of File` instead of statement
fail_compilation/ice15855.d(20): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/ice15855.d(19):        unmatched `{`
fail_compilation/ice15855.d(20): Error: found `End of File` when expecting `]`
fail_compilation/ice15855.d(20): Error: variable name expected after type `<error type>`, not `End of File`
---
*/

a[{for
