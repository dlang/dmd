/*
TEST_OUTPUT:
---
fail_compilation/ice12907.d(10): Error: template lambda has no value
---
*/

auto f(void function() g)
{
    return x => (*g)();
}
