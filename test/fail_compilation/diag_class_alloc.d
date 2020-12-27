/*
TEST_OUTPUT:
---
fail_compilation/diag_class_alloc.d(15): Error: found `size_t` when expecting `)`
fail_compilation/diag_class_alloc.d(15): Error: found `size` when expecting `;`
fail_compilation/diag_class_alloc.d(15): Error: declaration expected, not `)`
fail_compilation/diag_class_alloc.d(19): Error: unrecognized declaration
---
*/

// This test exists to ensure class allocators are now parse errors

class C
{
    new(size_t size)         // error message
    {
        return malloc(size);
    }
}
