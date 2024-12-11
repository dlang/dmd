/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/systemvariables_deprecation.d(22): Deprecation: `@safe` function `main` calling `middle`
    middle(); // nested deprecation
          ^
fail_compilation/systemvariables_deprecation.d(27):        which calls `systemvariables_deprecation.inferred`
    return inferred(); // no deprecation, inferredC is not explicit `@safe`
                   ^
fail_compilation/systemvariables_deprecation.d(33):        which wouldn't be `@safe` because of:
    x0 = null;
    ^
fail_compilation/systemvariables_deprecation.d(33):        cannot access `@system` variable `x0` in @safe code
---
*/

// test deprecation messages before -preview=systemVariables becomes default

void main() @safe
{
    middle(); // nested deprecation
}

auto middle()
{
    return inferred(); // no deprecation, inferredC is not explicit `@safe`
}

auto inferred()
{
    @system int* x0;
    x0 = null;
}
