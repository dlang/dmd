// check dsymbolSemantic analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff6.c(56): Error: enum member `failcstuff6.test_overflow.boom` initialization with `2147483647+1` causes overflow for type `int`
---
*/

/***************************************************/
#line 50

enum test_overflow
{
    three = 2147483645,
    two,
    one,
    boom,
};
