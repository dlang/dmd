/*
TEST_OUTPUT:
---
fail_compilation/ice11982.d(34): Error: basic type expected, not `scope`
void main() { new scope ( funk ) function }
                  ^
fail_compilation/ice11982.d(34): Error: found `scope` when expecting `;` following expression
void main() { new scope ( funk ) function }
                  ^
fail_compilation/ice11982.d(34):        expression: `new _error_`
void main() { new scope ( funk ) function }
              ^
fail_compilation/ice11982.d(34): Error: basic type expected, not `}`
fail_compilation/ice11982.d(34): Error: missing `{ ... }` for function literal
fail_compilation/ice11982.d(34): Error: C style cast illegal, use `cast(funk)function _error_()
{
}
`
void main() { new scope ( funk ) function }
                        ^
fail_compilation/ice11982.d(34): Error: found `}` when expecting `;` following expression
fail_compilation/ice11982.d(34):        expression: `cast(funk)function _error_()
{
}
`
void main() { new scope ( funk ) function }
                        ^
fail_compilation/ice11982.d(35): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/ice11982.d(34):        unmatched `{`
void main() { new scope ( funk ) function }
            ^
---
*/
void main() { new scope ( funk ) function }
