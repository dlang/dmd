/*
TEST_OUTPUT:
---
fail_compilation/fail120.d(12): Error: delegate fail120.Foo.__lambda4 function literals cannot be class members
fail_compilation/fail120.d(13): Error: delegate fail120.Foo.__lambda5 function literals cannot be class members
---
*/

class Foo
{
    int[2] nodes;
    auto left = (){ return nodes[0]; };
    auto right = (){ return nodes[1]; };
}
