/*
TEST_OUTPUT:
---
fail_compilation/e15876_5.d(19): Error: basic type expected, not `End of File`
fail_compilation/e15876_5.d(19): Error: semicolon expected to close `alias` declaration, not `End of File`
fail_compilation/e15876_5.d(19): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/e15876_5.d(18):        unmatched `{`
p[{alias
  ^
fail_compilation/e15876_5.d(19): Error: found `End of File` when expecting `]`
fail_compilation/e15876_5.d(19): Error: no identifier for declarator `p[()
{
alias ;
}
]`
---
*/
p[{alias
