// REQUIRED_ARGS: -vgc -o-
// PERMUTE_ARGS:

/***************** DeleteExp *******************/

struct S1 { }
struct S2 { this(int); }
struct S3 { this(int) @nogc; }

/*
TEST_OUTPUT:
---
fail_compilation/failvgc1.d(23): Error: The `delete` keyword has been removed.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/failvgc1.d(23): vgc: `delete` requires the GC
fail_compilation/failvgc1.d(24): Error: The `delete` keyword has been removed.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/failvgc1.d(24): vgc: `delete` requires the GC
fail_compilation/failvgc1.d(25): Error: The `delete` keyword has been removed.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/failvgc1.d(25): vgc: `delete` requires the GC
---
*/
void testDelete(int* p, Object o, S1* s)
{
    delete p;
    delete o;
    delete s;
}
