// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail_casting2.d(21): Error: type `int` is not an expression
    cast(void)(Type);
               ^
fail_compilation/fail_casting2.d(23): Error: template lambda has no type
    cast(void)(x => mixin(x)("mixin(x);"));
               ^
fail_compilation/fail_casting2.d(26): Error: template `Templ()` has no type
    cast(void)(Templ);
               ^
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
