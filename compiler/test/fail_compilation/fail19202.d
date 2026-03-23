// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail19202.d(12): Deprecation: variable `fail19202.X!().X` is deprecated
fail_compilation/fail19202.d(17):        `X` is declared here
---
*/

void main()
{
    auto b = X!();
}

template X()
{
    deprecated enum X = true;
}
