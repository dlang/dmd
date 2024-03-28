/**
Test language editions (currently experimental)

TEST_OUTPUT:
---
fail_compilation/editions.d(15): Error: scope parameter `x` may not be returned
---
*/
@__experimental_edition_latest
module editions;

@safe:
int* f(scope int* x)
{
    return x;
}
