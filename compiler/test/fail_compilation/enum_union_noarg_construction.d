/*
TEST_OUTPUT:
---
fail_compilation/enum_union_noarg_construction.d(13): Error: enum union `enum_union_noarg_construction.Value` cannot be constructed with no arguments; use `.init` instead
---
*/

enum union Value
{
    case Number(int),
}

auto value = Value();