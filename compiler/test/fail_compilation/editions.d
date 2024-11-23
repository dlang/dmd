/**
Test language editions (currently experimental)

TEST_OUTPUT:
---
fail_compilation/editions.d(17): Error: scope parameter `x` may not be returned
    return x;
           ^
---
*/
@__edition_latest_do_not_use
module editions;

@safe:
int* f(scope int* x)
{
    return x;
}
