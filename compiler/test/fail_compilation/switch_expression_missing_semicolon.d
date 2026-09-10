/*
TEST_OUTPUT:
---
fail_compilation/switch_expression_missing_semicolon.d(19): Error: found `}` when expecting `;` following expression
---
*/

enum union Value
{
    case Unit(),
}

void test()
{
    cast(void)switch (Value.Unit)
    {
        case Unit => 0,
    }
}

private int shouldNotCauseACascade;