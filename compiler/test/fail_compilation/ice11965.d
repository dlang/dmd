/*
TEST_OUTPUT:
---
fail_compilation/ice11965.d(12): Error: variable name expected after type `b*`, not `End of File`
fail_compilation/ice11965.d(12): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/ice11965.d(11):        unmatched `{`
fail_compilation/ice11965.d(12): Error: found `End of File` when expecting `]`
fail_compilation/ice11965.d(12): Error: variable name expected after type `<error type>`, not `End of File`
---
*/
u[{b*A,
