/*
TEST_OUTPUT:
---
fail_compilation/enum_union_constructor_read_this_partial_init.d(18): Error: cannot read `this` in constructor `enum_union_constructor_read_this_partial_init.Pointers.this` before it is initialized
---
*/

enum union Pointers
{
    case int*,
    case bool*;

    this(typeof(null) value, bool selectInt)
    {
        if (selectInt)
            this = cast(int*) null;

        assert(switch (this)
        {
            case int* => true,
            case bool* => true,
        });
    }
}