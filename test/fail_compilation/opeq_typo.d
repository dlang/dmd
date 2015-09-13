/*
TEST_OUTPUT:
---
fail_compilation/opeq_typo.d(15): Error: invalid token '=+', did you mean '+='?
fail_compilation/opeq_typo.d(16): Error: invalid token '=-', did you mean '-='?
fail_compilation/opeq_typo.d(17): Error: invalid token '=*', did you mean '*='?
fail_compilation/opeq_typo.d(19): Error: invalid token '=/', did you mean '/='?
fail_compilation/opeq_typo.d(21): Error: invalid token '=%', did you mean '%='?
---
*/

void test()
{
    int a, b;
    a =+ b;
    a =-	b;
    a =*
        b;
    a =/b;
    a =% b;

    a = +b;
    a = -b;
    a = *b;
}
