/*
TEST_OUTPUT:
---
fail_compilation/enum_union_unit_pattern_post_call_binding.d(15): Error: `=>` expected in switch expression arm
---
*/

enum union Value
{
    case Unit();
}

auto value = switch (Value.Unit)
{
    case Unit() binding => 0,
};
