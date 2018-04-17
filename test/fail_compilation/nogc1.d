// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

/***************** NewExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc1.d(17): Deprecation: class allocators have been deprecated, consider moving the allocation strategy outside of the class
fail_compilation/nogc1.d(18): Deprecation: class allocators have been deprecated, consider moving the allocation strategy outside of the class
---
*/

struct S1 { }
struct S2 { this(int); }
struct S3 { this(int) @nogc; }
struct S4 { new(size_t); }
struct S5 { @nogc new(size_t); }

/*
TEST_OUTPUT:
---
fail_compilation/nogc1.d(35): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
fail_compilation/nogc1.d(37): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
fail_compilation/nogc1.d(38): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
fail_compilation/nogc1.d(40): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
fail_compilation/nogc1.d(41): Error: `@nogc` function `nogc1.testNew` cannot call non-@nogc constructor `nogc1.S2.this`
fail_compilation/nogc1.d(42): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
fail_compilation/nogc1.d(43): Error: `@nogc` function `nogc1.testNew` cannot call non-@nogc allocator `nogc1.S4.new`
fail_compilation/nogc1.d(46): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
---
*/
@nogc void testNew()
{
    int* p1 = new int;

    int[] a1 = new int[3];
    int[][] a2 = new int[][](2, 3);

    S1* ps1 = new S1();
    S2* ps2 = new S2(1);
    S3* ps3 = new S3(1);
    S4* ps4 = new S4;
    S5* ps5 = new S5;   // no error

    Object o1 = new Object();
}

/*
TEST_OUTPUT:
---
fail_compilation/nogc1.d(63): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
fail_compilation/nogc1.d(65): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
fail_compilation/nogc1.d(66): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
fail_compilation/nogc1.d(68): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
fail_compilation/nogc1.d(69): Error: `@nogc` function `nogc1.testNewScope` cannot call non-@nogc constructor `nogc1.S2.this`
fail_compilation/nogc1.d(70): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
fail_compilation/nogc1.d(71): Error: `@nogc` function `nogc1.testNewScope` cannot call non-@nogc allocator `nogc1.S4.new`
---
*/
@nogc void testNewScope()
{
    scope int* p1 = new int;

    scope int[] a1 = new int[3];
    scope int[][] a2 = new int[][](2, 3);

    scope S1* ps1 = new S1();
    scope S2* ps2 = new S2(1);
    scope S3* ps3 = new S3(1);
    scope S4* ps4 = new S4;
    scope S5* ps5 = new S5;             // no error

    scope Object o1 = new Object();     // no error
    scope o2 = new Object();            // no error
}

/***************** DeleteExp *******************/

/*
TEST_OUTPUT:
---
fail_compilation/nogc1.d(93): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/nogc1.d(93): Error: cannot use `delete` in `@nogc` function `nogc1.testDelete`
fail_compilation/nogc1.d(94): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/nogc1.d(94): Error: cannot use `delete` in `@nogc` function `nogc1.testDelete`
fail_compilation/nogc1.d(95): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/nogc1.d(95): Error: cannot use `delete` in `@nogc` function `nogc1.testDelete`
---
*/
@nogc void testDelete(int* p, Object o, S1* s)
{
    delete p;
    delete o;
    delete s;
}
