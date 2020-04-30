// REQUIRED_ARGS:
// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
compilable/test5409b.d(20): Deprecation: `!a & b`: Boolean operator `!` has higher precedence than bitwise operator `&`.
compilable/test5409b.d(20):        Use one of the following instead: `!a && b` or `!(a & b)` or `(!a) & b`
compilable/test5409b.d(21): Deprecation: `!a | b`: Boolean operator `!` has higher precedence than bitwise operator `|`.
compilable/test5409b.d(21):        Use one of the following instead: `!a || b` or `!(a | b)` or `(!a) | b`
compilable/test5409b.d(22): Deprecation: `!a ^ b`: Boolean operator `!` has higher precedence than bitwise operator `^`.
compilable/test5409b.d(22):        Use one of the following instead: `!(a ^ b)` or `(!a) ^ b`
---
*/

void main()
{
    auto a = 12345;
    auto b = 54321;

    auto c = !a & b;
    auto d = !a | b;
    auto e = !a ^ b;
}
