/*
TEST_OUTPUT:
---
fail_compilation/better_string_diag.d(22): Error: cannot implicitly convert expression `"stringexp"` of type `string` to `char*`
fail_compilation/better_string_diag.d(22):        `c0` should be of type `const(char*)` or `immutable(char*)` and not `char*`
fail_compilation/better_string_diag.d(23): Error: cannot implicitly convert expression `"stringexp"` of type `string` to `wchar*`
fail_compilation/better_string_diag.d(23):        `c1` should be of type `const(wchar*)` or `immutable(wchar*)` and not `wchar*`
fail_compilation/better_string_diag.d(24): Error: cannot implicitly convert expression `"stringexp"` of type `string` to `dchar*`
fail_compilation/better_string_diag.d(24):        `c2` should be of type `const(dchar*)` or `immutable(dchar*)` and not `dchar*`
fail_compilation/better_string_diag.d(25): Error: cannot implicitly convert expression `"stringexp"` of type `string` to `char[]`
fail_compilation/better_string_diag.d(25):        `c3` should be of type `const(char[])` or `immutable(string)` and not `char[]`
fail_compilation/better_string_diag.d(26): Error: cannot implicitly convert expression `"stringexp"` of type `string` to `wchar[]`
fail_compilation/better_string_diag.d(26):        `c4` should be of type `const(wchar[])` or `immutable(wstring)` and not `wchar[]`
fail_compilation/better_string_diag.d(27): Error: cannot implicitly convert expression `"stringexp"` of type `string` to `dchar[]`
fail_compilation/better_string_diag.d(27):        `c5` should be of type `const(dchar[])` or `immutable(dstring)` and not `dchar[]`
---
*/
module better_string_diag;

void main()
{
    char*   c0 = "stringexp";
    wchar*  c1 = "stringexp";
    dchar*  c2 = "stringexp";
    char[]  c3 = "stringexp";
    wchar[] c4 = "stringexp";
    dchar[] c5 = "string" ~ "exp";
}
