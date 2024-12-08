/*
TEST_OUTPUT:
---
fail_compilation/diag8684.d(16): Error: found `;` when expecting `)`
fail_compilation/diag8684.d(17): Error: semicolon needed to end declaration of `x`, instead of `for`
    for (int q=0; q<10; ++q){
    ^
fail_compilation/diag8684.d(16):        `x` declared here
    int x = foo( 5, m;
        ^
---
*/

int foo(int n, int m)
{
    int x = foo( 5, m;
    for (int q=0; q<10; ++q){
       ++q;
    }
    return  2;
}
