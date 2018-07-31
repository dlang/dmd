/*
TEST_OUTPUT:
---
fail_compilation/failmemalloc.d(11): Deprecation: class allocators have been deprecated, consider moving the allocation strategy outside of the class
fail_compilation/failmemalloc.d(14): Error: member allocators not supported by CTFE
---
*/

struct S
{
    new(size_t sz) { return null; }
}

S* s = new S();
