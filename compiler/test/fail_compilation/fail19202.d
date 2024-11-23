// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail19202.d(13): Deprecation: variable `fail19202.X!().X` is deprecated
    auto b = X!();
             ^
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
