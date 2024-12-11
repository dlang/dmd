/*
 * TEST_OUTPUT:
---
fail_compilation/test15704.d(23): Error: cannot copy `void[]` to `void[]` in `@safe` code
    arr1[] = arr2[];  // overwrites pointers with arbitrary ints
           ^
fail_compilation/test15704.d(24): Error: cannot copy `const(void)[]` to `void[]` in `@safe` code
    arr1[] = new const(void)[3];
           ^
fail_compilation/test15704.d(25): Deprecation: cannot copy `int[]` to `void[]` in `@safe` code
    arr1[] = [5];
           ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=15704

void main() @safe {
    Object[] objs = [ new Object() ];
    void[] arr1 = objs;
    void[] arr2 = [ 123, 345, 567 ];

    arr1[] = arr2[];  // overwrites pointers with arbitrary ints
    arr1[] = new const(void)[3];
    arr1[] = [5];
}
