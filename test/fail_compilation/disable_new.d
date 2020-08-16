/*
TEST_OUTPUT:
---
fail_compilation/disable_new.d(24): Error: the `new` operator is disabled for type `disable_new.C`
fail_compilation/disable_new.d(25): Error: the `new` operator is disabled for type `S`
fail_compilation/disable_new.d(28): Error: allocator `disable_new.main.G.new` can only be `@disable`
---
*/

class C
{
    // force user of a type to use an external allocation strategy
    @disable new();
}

struct S
{
    // force user of a type to use an external allocation strategy
    @disable new();
}

void main()
{
    auto c = new C();
    auto s = new S();
    class G
    {
        new();
    }
}
