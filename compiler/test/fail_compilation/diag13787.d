// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/diag13787.d(16): Error: cannot slice function pointer `& main`
    auto a = (&main)[0..1];
                    ^
fail_compilation/diag13787.d(17): Error: cannot index function pointer `& main`
    auto x = (&main)[0];
                    ^
---
*/

void main()
{
    auto a = (&main)[0..1];
    auto x = (&main)[0];
}
