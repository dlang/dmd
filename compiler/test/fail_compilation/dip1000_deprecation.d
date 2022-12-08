/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dip1000_deprecation.d(17): Deprecation: `@safe` function `main` calling `inferred`
fail_compilation/dip1000_deprecation.d(25):        which would be `@system` because of:
fail_compilation/dip1000_deprecation.d(25):        scope variable `x0` may not be returned
fail_compilation/dip1000_deprecation.d(19): Deprecation: `@safe` function `main` calling `inferredC`
fail_compilation/dip1000_deprecation.d(36):        which calls `dip1000_deprecation.inferred`
fail_compilation/dip1000_deprecation.d(25):        which would be `@system` because of:
fail_compilation/dip1000_deprecation.d(25):        scope variable `x0` may not be returned
---
*/

void main() @safe
{
    inferred();
    inferredB(); // no deprecation, trusted
    inferredC(); // nested deprecation
}

auto inferred()
{
    scope int* x0;
    return x0;
}

auto inferredB() @trusted
{
    scope int* x1;
    return x1;
}

auto inferredC()
{
    return inferred(); // no deprecation, inferredC is not explicit `@safe`
}

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
