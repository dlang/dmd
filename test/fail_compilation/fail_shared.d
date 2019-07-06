/*
REQUIRED_ARGS:-preview=restrictiveshared
TEST_OUTPUT:
---
fail_compilation/fail_shared.d(15): Error: Trying to Access shared state `x`
fail_compilation/fail_shared.d(16): Error: Trying to Access shared state `x`
fail_compilation/fail_shared.d(17): Error: Trying to Access shared state `x`
fail_compilation/fail_shared.d(22): Error: Trying to Access shared state `x`
---
*/


int f1(shared int x)
{
    x += 7; // Error: Trying to accsess shared state x
    x = 22; // Error: Trying to accsess shared state x
    return x; // Error: Trying to accsess shared state x
}

int sync(shared int *x, int y)
{
    return x = y; // Error: Trying to accsess shared state x
}

