/* TEST_OUTPUT:
---
fail_compilation/generic3.c(103): Error: generic association type `float` can only appear once
fail_compilation/generic3.c(108): Error: no compatible generic association type for controlling expression type `long`
fail_compilation/generic3.c(112): Error: undefined identifier `E`
---
*/
#line 100

void test()
{
    int e1 = _Generic(1,
        int: 4,
        float: 5,
        float: 6);

    int e2 = _Generic(1LL, int:5);



    int e5 = _Generic(1, int:E);
}
