/*
TEST_OUTPUT:
---
fail_compilation/enum_union_bare_call.d(21): Error: enum union `SameSigFuns` does not overload ()
fail_compilation/enum_union_bare_call.d(33): Error: enum union `DiffSigFuns` does not overload ()
---
*/

// Calling an enum union value directly is not supported regardless of whether
// callable variants share the same signature or have differing signatures.

enum union SameSigFuns
{
    case int function(int);
    case int delegate(int);
}

void testSame()
{
    SameSigFuns f = delegate(int x) { return 0; };
    assert(f(42) == 0);
}

enum union DiffSigFuns
{
    case int function(int);
    case void delegate(string);
}

void testDiff()
{
    DiffSigFuns f = delegate(string s) {};
    f();
}
