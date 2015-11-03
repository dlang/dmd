/*
TEST_OUTPUT:
---
fail_compilation/ice15278.d(16): Error: alias this is not reachable as List already converts to List
---
*/

interface IAllocator {}

struct List
{
    IAllocator allocator;

    List unqualifiedCopy() const;

    alias unqualifiedCopy this;
}
