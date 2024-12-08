// REQUIRED_ARGS: -unittest
/*
TEST_OUTPUT:
---
fail_compilation/fail308.d(20): Error: template instance `object.RTInfo!(TestType)` recursive expansion
        struct TestType {}
        ^
---
*/

void main()
{
    MinHeap!(int) foo = new MinHeap!(int)();
}

class MinHeap(NodeType)
{
    unittest
    {
        struct TestType {}
        MinHeap!(TestType) foo;
    }
}
