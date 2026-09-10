/*
TEST_OUTPUT:
---
fail_compilation/enum_union_unit_pattern_post_call_binding.d(17): Error: `=>` expected in switch expression arm
fail_compilation/enum_union_unit_pattern_post_call_binding.d(17): Error: semicolon expected following auto declaration, not `=>`
fail_compilation/enum_union_unit_pattern_post_call_binding.d(17): Error: declaration expected, not `=>`
---
*/

enum union Value
{
    case Unit(),
}

auto value = switch (Value.Unit)
{
    case Unit() binding => 0,
};