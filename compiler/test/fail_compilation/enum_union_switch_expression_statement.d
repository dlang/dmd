/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_expression_statement.d(17): Error: switch expression has no effect; use `cast(void)` to discard its value
---
*/

enum union Test
{
    case Variant();
}

void main()
{
    switch (Test.Variant)
    {
        case Variant => ""
    }
}
