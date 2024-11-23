/*
TEST_OUTPUT:
---
fail_compilation/ice12907.d(12): Error: template lambda has no type
    return x => (*g)();
           ^
---
*/

auto f(void function() g)
{
    return x => (*g)();
}
