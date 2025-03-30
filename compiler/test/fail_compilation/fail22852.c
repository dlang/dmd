// https://issues.dlang.org/show_bug.cgi?id=22852
/* TEST_OUTPUT:
---
fail_compilation/fail22852.c(11): Error: `=`, `;` or `,` expected to end declaration instead of `"string"`
fail_compilation/fail22852.c(12): Error: character '`' is not a valid token
fail_compilation/fail22852.c(12): Error: character '`' is not a valid token
fail_compilation/fail22852.c(13): Error: expression expected, not `x"ff ff"`
fail_compilation/fail22852.c(14): Error: `=`, `;` or `,` expected to end declaration instead of `{`
---
*/
const char *rstring = r"string";
const char *wstring = `string`;
const char *hstring = x"ffff";
const char *qstring = q{string};
