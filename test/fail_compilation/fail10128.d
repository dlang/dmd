/*
TEST_OUTPUT:
---
fail_compilation/fail10128.d(15): Error: no property 'map' for type 'int[]'
fail_compilation/fail10128.d(20): Error: no property 'map' for type 'fail10128.B'
---
*/

import imports.fail10128a;

class B : A
{
    void test()
    {
        auto r = [1,2,3].map!(a=>a);    // succeeds to compile
    }
}
void main()
{
    auto r = B.map!(a=>a)([1,2,3]);    // also succeeds to compile
}

void test()
{
    import imports.fail10128b;  //std.algorithm;
    [1,2,3].map!(a=>a); // works
}
