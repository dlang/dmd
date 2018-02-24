// REQUIRED_ARGS: -vgc -o-
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
compilable/vgc1.d(93): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
compilable/vgc1.d(94): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
compilable/vgc1.d(95): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
---
*/

/***************** NewExp *******************/

struct S1 { }
struct S2 { this(int); }
struct S3 { this(int) @nogc; }
struct S4 { new(size_t); }
struct S5 { @nogc new(size_t); }

/*
TEST_OUTPUT:
---
compilable/vgc1.d(36): vgc: `new` causes a GC allocation
compilable/vgc1.d(38): vgc: `new` causes a GC allocation
compilable/vgc1.d(39): vgc: `new` causes a GC allocation
compilable/vgc1.d(41): vgc: `new` causes a GC allocation
compilable/vgc1.d(42): vgc: `new` causes a GC allocation
compilable/vgc1.d(43): vgc: `new` causes a GC allocation
compilable/vgc1.d(47): vgc: `new` causes a GC allocation
---
*/

void testNew()
{
    int* p1 = new int;

    int[] a1 = new int[3];
    int[][] a2 = new int[][](2, 3);

    S1* ps1 = new S1();
    S2* ps2 = new S2(1);
    S3* ps3 = new S3(1);
    S4* ps4 = new S4;   // no error
    S5* ps5 = new S5;   // no error

    Object o1 = new Object();
}

/*
TEST_OUTPUT:
---
compilable/vgc1.d(64): vgc: `new` causes a GC allocation
compilable/vgc1.d(66): vgc: `new` causes a GC allocation
compilable/vgc1.d(67): vgc: `new` causes a GC allocation
compilable/vgc1.d(69): vgc: `new` causes a GC allocation
compilable/vgc1.d(70): vgc: `new` causes a GC allocation
compilable/vgc1.d(71): vgc: `new` causes a GC allocation
---
*/

void testNewScope()
{
    scope int* p1 = new int;

    scope int[] a1 = new int[3];
    scope int[][] a2 = new int[][](2, 3);

    scope S1* ps1 = new S1();
    scope S2* ps2 = new S2(1);
    scope S3* ps3 = new S3(1);
    scope S4* ps4 = new S4;             // no error
    scope S5* ps5 = new S5;             // no error

    scope Object o1 = new Object();     // no error
    scope o2 = new Object();            // no error
    scope Object o3;
    o3 = o2;                            // no error
}

/***************** DeleteExp *******************/

/*
TEST_OUTPUT:
---
compilable/vgc1.d(93): vgc: `delete` requires the GC
compilable/vgc1.d(94): vgc: `delete` requires the GC
compilable/vgc1.d(95): vgc: `delete` requires the GC
---
*/
void testDelete(int* p, Object o, S1* s)
{
    delete p;
    delete o;
    delete s;
}
