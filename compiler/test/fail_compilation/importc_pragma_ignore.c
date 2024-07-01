/* TEST_OUTPUT:
---
fail_compilation/importc_pragma_ignore.c(23): Error: left parenthesis expected to follow `#pragma importc_ignore` not `\n`
fail_compilation/importc_pragma_ignore.c(24): Error: `+`, `-`, or a colon is expected to follow `#pragma importc_ignore(` not `\n`
fail_compilation/importc_pragma_ignore.c(25): Error: `+`, `-`, or a colon is expected to follow `#pragma importc_ignore(` not `foo`
fail_compilation/importc_pragma_ignore.c(26): Error: `+`, `-`, or a colon is expected to follow `#pragma importc_ignore(` not `function_decl`
fail_compilation/importc_pragma_ignore.c(27): Error: identifier expected to follow `#pragma importc_ignore(+` not `\n`
fail_compilation/importc_pragma_ignore.c(28): Error: identifier expected to follow `#pragma importc_ignore(-` not `\n`
fail_compilation/importc_pragma_ignore.c(29): Error: identifier or right parenthesis expected following `#pragma importc_ignore(... :` not `\n`
fail_compilation/importc_pragma_ignore.c(30): Error: identifier expected to follow `#pragma importc_ignore(+` not `123`
fail_compilation/importc_pragma_ignore.c(31): Error: `function_decl` or `function_def` expected to follow `#pragma importc_ignore(+` not `not_a_category`
fail_compilation/importc_pragma_ignore.c(32): Error: `+`, `-`, or a colon is expected to follow `#pragma importc_ignore(` not `\n`
fail_compilation/importc_pragma_ignore.c(33): Error: `+`, `-`, or a colon is expected to follow `#pragma importc_ignore(` not `function_def`
fail_compilation/importc_pragma_ignore.c(34): Error: `+`, `-`, or a colon is expected to follow `#pragma importc_ignore(` not `\n`
fail_compilation/importc_pragma_ignore.c(35): Error: identifier or right parenthesis expected following `#pragma importc_ignore(... :` not `123`
fail_compilation/importc_pragma_ignore.c(36): Error: comma or right parenthesis expected following `#pragma importc_ignore(... : foo` not `\n`
fail_compilation/importc_pragma_ignore.c(37): Error: identifier or right parenthesis expected following `#pragma importc_ignore(... :` not `\n`
fail_compilation/importc_pragma_ignore.c(38): Error: identifier or right parenthesis expected following `#pragma importc_ignore(... :` not `,`
fail_compilation/importc_pragma_ignore.c(39): Error: identifier or right parenthesis expected following `#pragma importc_ignore(... :` not `\n`
---
*/

#pragma importc_ignore
#pragma importc_ignore(
#pragma importc_ignore(foo
#pragma importc_ignore(function_decl
#pragma importc_ignore(+
#pragma importc_ignore(-
#pragma importc_ignore(:
#pragma importc_ignore(+123
#pragma importc_ignore(+not_a_category
#pragma importc_ignore(+function_decl
#pragma importc_ignore(+function_decl function_def
#pragma importc_ignore(+function_decl -function_def
#pragma importc_ignore(+function_decl -function_def : 123
#pragma importc_ignore(+function_decl -function_def : foo
#pragma importc_ignore(+function_decl -function_def : foo,
#pragma importc_ignore(+function_decl -function_def : ,
#pragma importc_ignore(+function_decl -function_def :
void foo(void)
{}
