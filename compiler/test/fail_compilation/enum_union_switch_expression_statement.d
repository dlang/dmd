/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_expression_statement.d(20): Error: found `}` when expecting `:`
fail_compilation/enum_union_switch_expression_statement.d(21): Error: matching `}` expected following compound statement, not `End of File`
fail_compilation/enum_union_switch_expression_statement.d(16):        unmatched `{`
---
*/

enum union Test
{
    case Variant(),
}

void main()
{
    switch (Test.Variant)
    {
        case Variant => ""
    }
}