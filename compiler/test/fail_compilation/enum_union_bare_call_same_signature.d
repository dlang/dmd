/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_call_same_signature.d(20): Error: enum union `Funs` does not overload ()
---
*/

// Calling an enum union value directly (`f(42)`) is not a supported feature:
// there is no synthesized `opCall`, so this fails regardless of whether the
// callable variants share the same signature.
enum union Funs
{
    case int function(int),
    case int delegate(int),
}

void test()
{
    Funs f = delegate(int x) { return 0; };
    assert(f(42) == 0);
}
