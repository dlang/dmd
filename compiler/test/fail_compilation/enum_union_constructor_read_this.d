/*
TEST_OUTPUT:
---
fail_compilation/enum_union_constructor_read_this.d(17): Error: cannot read `this` in constructor `enum_union_constructor_read_this.Pointers1.this` before it is initialized
fail_compilation/enum_union_constructor_read_this.d(36): Error: cannot read `this` in constructor `enum_union_constructor_read_this.Pointers2.this` before it is initialized
---
*/

// 1. Read before any initialization
enum union Pointers1
{
    case int*;
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

// 2. Read after partial branch initialization
enum union Pointers2
{
    case int*;
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
