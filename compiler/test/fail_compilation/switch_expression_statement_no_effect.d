/*
TEST_OUTPUT:
---
fail_compilation/switch_expression_statement_no_effect.d(16): Error: switch expression has no effect; use `cast(void)` to discard its value
---
*/

enum union Value
{
    case Unit(),
    case Number(int),
}

void main()
{
    switch (Value.Unit)
    {
        case Unit value => "unit",
        case Number value => "number",
    }
}