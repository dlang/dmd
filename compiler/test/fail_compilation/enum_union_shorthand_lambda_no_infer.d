/*
TEST_OUTPUT:
---
fail_compilation/enum_union_shorthand_lambda_no_infer.d(20): Error: template lambda has no value
---
*/

// The shorthand single-param lambda syntax (`n => n`) cannot infer `n`'s
// type here: the assignment target is the enum union struct itself, not a
// concrete callable type, so there is nothing for the compiler to infer the
// parameter type from.
enum union Funs
{
    case int delegate(int),
    case int function(int),
}

void test()
{
    Funs f = n => n;
}
