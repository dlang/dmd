// check importAll analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff3.c(54): Error: redeclaration of `S22061`
fail_compilation/failcstuff3.c(100): Error: static assert:  `0` is false
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
// https://github.com/dlang/dmd/issues/23226
// C23 6.7.12 — failing single-argument _Static_assert still diagnoses
#line 100
_Static_assert(0);
