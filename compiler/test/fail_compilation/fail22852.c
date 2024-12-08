// https://issues.dlang.org/show_bug.cgi?id=22852
/* TEST_OUTPUT:
---
fail_compilation/fail22852.c(21): Error: `=`, `;` or `,` expected to end declaration instead of `"string"`
const char *rstring = r"string";
                       ^
fail_compilation/fail22852.c(22): Error: character '`' is not a valid token
const char *wstring = `string`;
                      ^
fail_compilation/fail22852.c(22): Error: character '`' is not a valid token
const char *wstring = `string`;
                             ^
fail_compilation/fail22852.c(23): Error: expression expected, not `x"ff ff"`
const char *hstring = x"ffff";
                      ^
fail_compilation/fail22852.c(24): Error: `=`, `;` or `,` expected to end declaration instead of `{`
const char *qstring = q{string};
                       ^
---
*/
const char *rstring = r"string";
const char *wstring = `string`;
const char *hstring = x"ffff";
const char *qstring = q{string};
