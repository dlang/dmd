/* TEST_OUTPUT:
---
fail_compilation/generic.c(103): Error: generic association type `float` can only appear once
fail_compilation/generic.c(108): Error: no compatible generic association type for controlling expression type `long`
fail_compilation/generic.c(110): Error: undefined identifier `T`
fail_compilation/generic.c(112): Error: undefined identifier `E`
---
*/

int test1() { return _Generic(1, int:5, long long:6); }
_Static_assert(test1() == 5, "in");

int test2() { return _Generic(1, default:5, long long:6); }
_Static_assert(test2() == 5, "in");

int test3()
{
    return _Generic(1,
        long: 5,
        int: 4,
        long long: 6);
}
_Static_assert(test3() == 4 + (sizeof(long) == 4), "in");

int test4()
{
    return _Generic(1.0,
        long double: 5,
        double: 4);
}
_Static_assert(test4() == 4 + (sizeof(long double) == 8), "in");

#line 100

void test()
{
    int e1 = _Generic(1,
        int: 4,
        float: 5,
        float: 6);

    int e2 = _Generic(1LL, int:5);

    int e4 = _Generic(1, T:5);

    int e5 = _Generic(1, int:E);
}
