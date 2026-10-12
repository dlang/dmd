/**
Test 2024 language edition semantic errors

TEST_OUTPUT:
---
fail_compilation/editions.d(16): Error: scope parameter `x` may not be returned
fail_compilation/editions.d(23): Error: `case` with a runtime variable is obsolete
---
*/

module editions 2024;

@safe:
int* f(scope int* x)
{
    return x; // DIP1000
}

void g(const int i)
{
    switch (5)
    {
        case i: return; // runtime case variables
        default:
    }
}
