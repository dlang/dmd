/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dip1000_deprecation.d(23): Deprecation: escaping reference to stack allocated value returned by `S(null)`
fail_compilation/dip1000_deprecation.d(24): Deprecation: escaping reference to stack allocated value returned by `createS()`
fail_compilation/dip1000_deprecation.d(27): Deprecation: returning `s.incorrectReturnRef()` escapes a reference to local variable `s`
---
*/

@safe:

struct S
{
    int* ptr;
    int* incorrectReturnRef() scope return @trusted {return ptr;}
}

S createS() { return S.init; }

int* escape()
{
    return S().incorrectReturnRef();
    return createS().incorrectReturnRef();

    S s;
    return s.incorrectReturnRef();
}
