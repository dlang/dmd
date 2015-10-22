// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail_casting2.d(15): Error: type int has no value
fail_compilation/fail_casting2.d(17): Error: template lambda has no value
fail_compilation/fail_casting2.d(20): Error: template Templ() has no value
---
*/

void test15214()
{
    alias Type = int;
    cast(void)(Type);

    cast(void)(x => mixin(x)("mixin(x);"));

    template Templ() {}
    cast(void)(Templ);
}
