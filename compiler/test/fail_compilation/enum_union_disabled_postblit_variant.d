/*
TEST_OUTPUT:
---
fail_compilation/enum_union_disabled_postblit_variant.d(14): Error: struct `enum_union_disabled_postblit_variant.DisabledPostBlit` is not copyable because it has a disabled postblit
---
*/

struct DisabledPostBlit
{
    int x;
    @disable this(this);
}

enum union HasDisabledPostBlit
{
    case Wrapped(DisabledPostBlit),
    case Flag(bool),
}
