/*
TEST_OUTPUT:
---
fail_compilation/enum_union_disabled_copy_variant.d(16): Error: copy constructor `enum_union_disabled_copy_variant.DisabledCopy.this` cannot be used because it is annotated with `@disable`
fail_compilation/enum_union_disabled_copy_variant.d(28): Error: struct `enum_union_disabled_copy_variant.DisabledPostBlit` is not copyable because it has a disabled postblit
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
    case Wrapped(DisabledCopy);
    case Flag(bool);
}

struct DisabledPostBlit
{
    int x;
    @disable this(this);
}

enum union HasDisabledPostBlit
{
    case Wrapped(DisabledPostBlit);
    case Flag(bool);
}
