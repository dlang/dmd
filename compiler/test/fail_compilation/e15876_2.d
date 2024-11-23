/*
TEST_OUTPUT:
---
fail_compilation/e15876_2.d(18): Error: identifier expected following `template`
fail_compilation/e15876_2.d(18): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_2.d(17):        unmatched `{`
o[{template
  ^
fail_compilation/e15876_2.d(18): Error: found `End of File` when expecting `]`
fail_compilation/e15876_2.d(18): Error: no identifier for declarator `o[()
{
;
}
]`
---
*/
o[{template
