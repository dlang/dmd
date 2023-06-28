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


/***************************************************/
#line 100

enum test_enum_fits
{
    intMinFits     = -2147483648,
    intMaxFits     = 4294967295,
    firstMinError  = -2147483649,
    firstMaxError  = 4294967296,
    lastMaxError   = 0xffffffff7fffffff,
    firstBlindSpot = 0xffffffff80000000,
    lastBlindSpot  = 0xffffffffffffffff,
};
