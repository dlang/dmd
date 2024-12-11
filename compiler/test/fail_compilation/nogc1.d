// REQUIRED_ARGS: -o-

/***************** NewExp *******************/

struct S1 { }
struct S2 { this(int); }
struct S3 { this(int) @nogc; }

/*
TEST_OUTPUT:
---
fail_compilation/nogc1.d(67): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
    int* p1 = new int;
              ^
fail_compilation/nogc1.d(69): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
    int[] a1 = new int[3];
               ^
fail_compilation/nogc1.d(70): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
    int[][] a2 = new int[][](2, 3);
                 ^
fail_compilation/nogc1.d(72): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
    S1* ps1 = new S1();
              ^
fail_compilation/nogc1.d(73): Error: `@nogc` function `nogc1.testNew` cannot call non-@nogc constructor `nogc1.S2.this`
    S2* ps2 = new S2(1);
              ^
fail_compilation/nogc1.d(74): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
    S3* ps3 = new S3(1);
              ^
fail_compilation/nogc1.d(76): Error: cannot use `new` in `@nogc` function `nogc1.testNew`
    Object o1 = new Object();
                ^
fail_compilation/nogc1.d(81): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
    scope int* p1 = new int;
                    ^
fail_compilation/nogc1.d(83): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
    scope int[] a1 = new int[3];
                     ^
fail_compilation/nogc1.d(84): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
    scope int[][] a2 = new int[][](2, 3);
                       ^
fail_compilation/nogc1.d(86): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
    scope S1* ps1 = new S1();
                    ^
fail_compilation/nogc1.d(87): Error: `@nogc` function `nogc1.testNewScope` cannot call non-@nogc constructor `nogc1.S2.this`
    scope S2* ps2 = new S2(1);
                    ^
fail_compilation/nogc1.d(88): Error: cannot use `new` in `@nogc` function `nogc1.testNewScope`
    scope S3* ps3 = new S3(1);
                    ^
fail_compilation/nogc1.d(98): Error: the `delete` keyword is obsolete
    delete p;
    ^
fail_compilation/nogc1.d(98):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
fail_compilation/nogc1.d(99): Error: the `delete` keyword is obsolete
    delete o;
    ^
fail_compilation/nogc1.d(99):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
fail_compilation/nogc1.d(100): Error: the `delete` keyword is obsolete
    delete s;
    ^
fail_compilation/nogc1.d(100):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
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

    Object o1 = new Object();
}

@nogc void testNewScope()
{
    scope int* p1 = new int;

    scope int[] a1 = new int[3];
    scope int[][] a2 = new int[][](2, 3);

    scope S1* ps1 = new S1();
    scope S2* ps2 = new S2(1);
    scope S3* ps3 = new S3(1);

    scope Object o1 = new Object();     // no error
    scope o2 = new Object();            // no error
}

/***************** DeleteExp *******************/

@nogc void testDelete(int* p, Object o, S1* s)
{
    delete p;
    delete o;
    delete s;
}
