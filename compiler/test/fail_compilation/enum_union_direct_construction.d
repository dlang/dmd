/*
TEST_OUTPUT:
---
fail_compilation/enum_union_direct_construction.d(15): Error: enum union `enum_union_direct_construction.Value` cannot be constructed directly; use a variant
fail_compilation/enum_union_direct_construction.d(16): Error: enum union `enum_union_direct_construction.Value` cannot be constructed directly; use a variant
---
*/

enum union Value
{
    case Number(int);
}

Value value = Value.Number(1);
auto direct = Value(value);
auto allocated = new Value(value);