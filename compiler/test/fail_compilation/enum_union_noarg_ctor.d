/*
TEST_OUTPUT:
---
fail_compilation/enum_union_noarg_ctor.d(13): Error: enum union `enum_union_noarg_ctor.NoArgCtor` cannot have a no-argument constructor; use `.init` instead
fail_compilation/enum_union_noarg_ctor.d(21): Error: enum union `enum_union_noarg_ctor.NoArgCall` cannot be constructed with no arguments; use `.init` instead
---
*/

enum union NoArgCtor
{
    case Number(int);

    this() {}
}

enum union NoArgCall
{
    case Number(int);
}

auto val = NoArgCall();
