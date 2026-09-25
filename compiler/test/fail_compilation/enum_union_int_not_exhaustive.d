/*
TEST_OUTPUT:
---
fail_compilation/enum_union_int_not_exhaustive.d(15): Error: switch expression is not exhaustive; missing pattern `Num(_)`
---
*/

enum union IntVal
{
    case Num(int);
}

string test(IntVal v)
{
    return switch (v)
    {
        case Num(number) if (number == 0) => "zero",
        case Num(number) if (number == 1) => "one",
    };
}
