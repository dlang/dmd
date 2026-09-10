/*
TEST_OUTPUT:
---
fail_compilation/enum_union_constructor_read_this_before_init.d(15): Error: cannot read `this` in constructor `enum_union_constructor_read_this_before_init.Pointers.this` before it is initialized
---
*/

enum union Pointers
{
    case int*,
    case bool*;

    this(typeof(null) value)
    {
        this = switch (this)
        {
            case int* => cast(bool*) null,
            case bool* => new bool(),
        };
    }
}