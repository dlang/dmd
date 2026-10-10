/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_static_foreach.d(24): Error: redundant match arm; pattern is unreachable
fail_compilation/enum_union_switch_static_foreach.d(31): Error: switch expression is not exhaustive; missing pattern `double`
---
*/

template AliasSeq(T...) { alias AliasSeq = T; }

enum union Number
{
    case error();
    case int;
    case double;
}

int testDup(Number a)
{
    return switch (a)
    {
        case error() => 0,
        static foreach (T; AliasSeq!(int, int))
            case T i => i,
        case double d => cast(int)d,
    };
}

int testNonExhaustive(Number a)
{
    return switch (a)
    {
        case error() => 0,
        static foreach (T; AliasSeq!(int))
            case T i => i,
    };
}
