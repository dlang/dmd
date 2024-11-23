// https://issues.dlang.org/show_bug.cgi?id=22686

/*
TEST_OUTPUT:
---
fail_compilation/test22686.d(17): Error: `this` is only defined in non-static member functions, not `create`
        auto self = &this;
                     ^
---
*/

struct S
{
    int[] data;
    static auto create()
    {
        auto self = &this;
        return {
            assert(data.length);
            return self;
        };
    }
}
