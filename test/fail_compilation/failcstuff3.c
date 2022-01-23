// check importAll analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff3.c(54): Error: union `failcstuff3.S22061` conflicts with struct `failcstuff3.S22061` at fail_compilation/failcstuff3.c(50)
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

