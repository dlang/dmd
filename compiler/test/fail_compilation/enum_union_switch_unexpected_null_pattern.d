/*
TEST_OUTPUT:
---
fail_compilation/enum_union_switch_unexpected_null_pattern.d(18): Error: switch expression value and expression patterns are not supported; use a named variant or type pattern
---
*/

enum union Pointers
{
    case int*,
    case bool*,
}

string classify(Pointers pointers)
{
    return switch (pointers)
    {
        case null => "null",
        case int* => "integer",
        case bool* => "boolean",
    };
}