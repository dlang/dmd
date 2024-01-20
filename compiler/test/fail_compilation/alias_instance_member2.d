/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/alias_instance_member2.d(18): Deprecation: cannot alias member of variable `f`
fail_compilation/alias_instance_member2.d(18):        Use `typeof(f)` instead to preserve behaviour
---
*/

struct Foo
{
    int v;
}

struct Bar
{
    Foo f;
    alias v = f.v;
}
