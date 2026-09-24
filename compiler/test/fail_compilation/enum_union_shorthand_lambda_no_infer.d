/*
TEST_OUTPUT:
---
fail_compilation/enum_union_shorthand_lambda_no_infer.d(23): Error: `enum_union_shorthand_lambda_no_infer.Funs.__ctor` called with argument types `((n) => n)` matches multiple overloads after qualifier conversion:
fail_compilation/enum_union_shorthand_lambda_no_infer.d(15):     `enum_union_shorthand_lambda_no_infer.Funs.this(int delegate(int) __enumPayloadParam12)`
and:
fail_compilation/enum_union_shorthand_lambda_no_infer.d(15):     `enum_union_shorthand_lambda_no_infer.Funs.this(string function(string) __enumPayloadParam13)`
---
*/

// The shorthand single-param lambda syntax (`n => n`) cannot infer `n`'s
// type here: the assignment target is the enum union struct itself with
// ambiguous parameter types (`int` vs `string`), so there is no unique
// parameter type for the compiler to infer from.
enum union Funs
{
    case int delegate(int);
    case string function(string);
}

void test()
{
    Funs f = n => n;
}

