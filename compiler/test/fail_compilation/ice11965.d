/*
TEST_OUTPUT:
---
fail_compilation/ice11965.d(18): Error: no identifier for declarator `b*`
fail_compilation/ice11965.d(18): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/ice11965.d(17):        unmatched `{`
u[{b*A,
  ^
fail_compilation/ice11965.d(18): Error: found `End of File` when expecting `]`
fail_compilation/ice11965.d(18): Error: no identifier for declarator `u[()
{
b* A;
}
]`
---
*/
u[{b*A,
