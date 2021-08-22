// check importAll analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff3.c(54): Error: redeclaration of `S22061`
fail_compilation/failcstuff3.c(100): Error: can only `*` a pointer, not a `int`
fail_compilation/failcstuff3.c(157): Error: variable `failcstuff3.T22106.f1` no definition of struct `S22106_t`
---
*/

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22061
#line 50
struct S22061
{
    int field;
};
typedef union S22061 S22061;

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
