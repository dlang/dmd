/*
TEST_OUTPUT:
---
fail_compilation/fail120.d(16): Error: accessing non-static variable `nodes` requires an instance of `Foo`
    auto left = (){ return nodes[0]; };
                           ^
fail_compilation/fail120.d(17): Error: accessing non-static variable `nodes` requires an instance of `Foo`
    auto right = (){ return nodes[1]; };
                            ^
---
*/

class Foo
{
    int[2] nodes;
    auto left = (){ return nodes[0]; };
    auto right = (){ return nodes[1]; };
}
