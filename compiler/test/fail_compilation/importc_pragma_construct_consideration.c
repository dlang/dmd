
#pragma function_decl
#pragma function_def
#pragma function_def(
#pragma function_def(,
#pragma function_def(foo
#pragma function_def(consider
#pragma function_def(ignore
#pragma function_def(ignore foo
#pragma function_def(ignore, foo
#pragma function_def(ignore, foo,
#pragma function_def(ignore, foo, bar
#pragma function_def(ignore, foo, bar) rubbish
void foo(void)
{}

/* TEST_OUTPUT:
---
fail_compilation/importc_pragma_construct_consideration.c(2): Error: left parenthesis expected to follow `#pragma function_decl` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(3): Error: left parenthesis expected to follow `#pragma function_def` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(4): Error: `consider` or `ignore` expected to follow `#pragma function_def(` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(5): Error: `consider` or `ignore` expected to follow `#pragma function_def(` not `,`
fail_compilation/importc_pragma_construct_consideration.c(6): Error: `consider` or `ignore` expected to follow `#pragma function_def(` not `foo`
fail_compilation/importc_pragma_construct_consideration.c(7): Error: comma expected to follow `#pragma function_def(consider` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(8): Error: comma expected to follow `#pragma function_def(ignore` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(9): Error: comma expected to follow `#pragma function_def(ignore` not `foo`
fail_compilation/importc_pragma_construct_consideration.c(10): Error: comma or right parenthesis expected following `#pragma function_def(ignore, foo` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(11): Error: identifier or right parenthesis expected following `#pragma function_def(ignore,` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(12): Error: comma or right parenthesis expected following `#pragma function_def(ignore, bar` not `\n`
fail_compilation/importc_pragma_construct_consideration.c(13): Error: `#pragma function_def(ignore)` should not be followed by anything on the same line, it has been followed by `rubbish`
---
*/
