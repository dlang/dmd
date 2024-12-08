/*
TEST_OUTPUT:
---
fail_compilation/e15876_4.d(30): Error: found `)` when expecting `(`
typeof){for
      ^
fail_compilation/e15876_4.d(31): Error: found `End of File` when expecting `(`
fail_compilation/e15876_4.d(31): Error: found `End of File` instead of statement
fail_compilation/e15876_4.d(31): Error: expression expected, not `End of File`
fail_compilation/e15876_4.d(31): Error: found `End of File` when expecting `;` following `for` condition
fail_compilation/e15876_4.d(31): Error: expression expected, not `End of File`
fail_compilation/e15876_4.d(31): Error: found `End of File` when expecting `)`
fail_compilation/e15876_4.d(31): Error: found `End of File` instead of statement
fail_compilation/e15876_4.d(31): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_4.d(30):        unmatched `{`
typeof){for
       ^
fail_compilation/e15876_4.d(31): Error: found `End of File` when expecting `)`
fail_compilation/e15876_4.d(31): Error: no identifier for declarator `typeof(()
{
for (__error__
 __error; __error)
{
__error__
}
}
)`
---
*/
typeof){for
