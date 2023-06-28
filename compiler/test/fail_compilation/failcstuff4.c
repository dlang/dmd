// check importAll analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff4.c(100): Error: can only `*` a pointer, not a `int`
fail_compilation/failcstuff4.c(157): Error: variable `failcstuff4.T22106.f1` - no definition of struct `S22106_t`
fail_compilation/failcstuff4.c(157):        see https://dlang.org/spec/struct.html#opaque_struct_unions
fail_compilation/failcstuff4.c(157):        perhaps declare a variable with pointer type `S22106_t*` instead
---
*/

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22103
#line 100
int test22103(int array[*4]);

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22106
#line 150
typedef struct S22106
{
    int field;
} S22106_t;

struct T22106
{
    struct S22106_t f1;
};
