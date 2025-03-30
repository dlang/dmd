/* DISABLED: win32 linux32
 */

// https://issues.dlang.org/show_bug.cgi?id=23875
// https://issues.dlang.org/show_bug.cgi?id=23880

int __attribute__((vector_size(16))) neptune()
{
    int __attribute__((vector_size (16))) v = { 4,1,2,3 };
    return v;
}

__attribute__((__vector_size__(16))) int pluto(int i)
{
    int __attribute__((__vector_size__ (16))) * p1;
    int * __attribute__((__vector_size__ (16))) p2;

    int __attribute__((__vector_size__ (16))) v1;
    __attribute__((__vector_size__ (16))) int v2;

    v1 = (__attribute__((__vector_size__ (16))) int) {4,1,2,3};

    p1 = p2;
    *p1 = v1;
    v1 = (__attribute__((__vector_size__ (16))) int) v2;

    return i ? v1 : v2;
}

// https://issues.dlang.org/show_bug.cgi?id=24125

typedef int   __i128 __attribute__ ((__vector_size__ (16), __may_alias__));

__i128 test1()
{
    return (__i128){ 1, 2, 3, 4 };
}

typedef float __m128 __attribute__ ((__vector_size__ (16), __may_alias__));

__m128 test2()
{
    return (__m128){ 1, 2, 3, 4 };
}
