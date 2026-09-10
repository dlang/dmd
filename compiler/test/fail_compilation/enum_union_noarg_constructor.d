/*
TEST_OUTPUT:
---
fail_compilation/enum_union_noarg_constructor.d(12): Error: enum union `enum_union_noarg_constructor.Value` cannot have a no-argument constructor; use `.init` instead
---
*/

enum union Value
{
    case Number(int);

    this() {}
}