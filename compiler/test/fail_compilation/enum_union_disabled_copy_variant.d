/*
TEST_OUTPUT:
---
fail_compilation/enum_union_disabled_copy_variant.d(15): Error: copy constructor `enum_union_disabled_copy_variant.DisabledCopy.this` cannot be used because it is annotated with `@disable`
---
*/

struct DisabledCopy
{
    int x;
    @disable this(ref DisabledCopy);
    this(int v) { x = v; }
}

enum union HasDisabledCopy
{
    case Wrapped(DisabledCopy),
    case Flag(bool),
}
