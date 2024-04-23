/*
REQUIRED_ARGS: -cpp=
TEST_OUTPUT:
---
fail_compilation/test23672.i(10): Error: found `End of File` when expecting `)`
fail_compilation/test23672.i(10): Error: `=`, `;` or `,` expected to end declaration instead of `End of File`
---
*/
extern int feof (FILE *__strea
