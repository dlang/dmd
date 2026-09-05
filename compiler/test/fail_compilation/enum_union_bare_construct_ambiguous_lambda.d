/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_construct_ambiguous_lambda.d(18): Error: `() { }` is ambiguous between variants `void function()` and `void delegate()` of enum union `enum_union_bare_construct_ambiguous_lambda.Funs`
---
*/

enum union Funs
{
    case void function(),
    case void delegate(),
}

void test()
{
    // A non-capturing lambda literal is implicitly convertible to *either* a
    // function pointer or a delegate with the same signature.
    Funs f = (){};
}
