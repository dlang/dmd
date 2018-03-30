/*
TEST_OUTPUT:
---
fail_compilation/disable_new.d(23): Error: allocator `disable_new.C.new` is not callable because it is annotated with `@disable`
fail_compilation/disable_new.d(24): Error: allocator `disable_new.S.new` is not callable because it is annotated with `@disable`
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
}
