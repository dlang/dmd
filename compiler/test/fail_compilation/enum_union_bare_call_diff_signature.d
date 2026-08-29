/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_call_diff_signature.d(23): Error: enum union `Funs` does not overload ()
---
*/

// Same as enum_union_bare_call_same_signature.d, but with two variants that
// have completely different callable signatures. Direct-call syntax is not
// supported at all currently, so this fails identically either way; even if
// it were ever added, differing signatures could never work since the call
// site needs one statically-known parameter/return type to type-check
// against.
enum union Funs
{
    case int function(int),
    case void delegate(string),
}

void test()
{
    Funs f = delegate(string s) {};
    f();
}
