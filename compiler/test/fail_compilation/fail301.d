/*
TEST_OUTPUT:
---
fail_compilation/fail301.d(15): Error: accessing non-static variable `guard` requires an instance of `bug3305b`
    auto guard = bug3305b!(0).guard;
                 ^
fail_compilation/fail301.d(26): Error: template instance `fail301.bug3305!0` error instantiating
    bug3305!(0) a;
    ^
---
*/

struct bug3305(alias X = 0)
{
    auto guard = bug3305b!(0).guard;
}

struct bug3305b(alias X = 0)
{
    bug3305!(X) goo;
    auto guard = 0;
}

void test()
{
    bug3305!(0) a;
}
