/* PERMUTE_ARGS: -O
 * Test floating point code generation
 */

import core.stdc.stdio;
import core.stdc.stdlib;

double value_1() {
    return 1;
}

double value_2() {
    return 2;
}

/***************************************/

void testcse1(T)()  // common subexpressions
{
    T a = value_1();
    T b = value_2();
    T x = a*a + a*a + a*a + a*a + a*a + a*a + a*a +
               a*b + a*b;
    printf("%g\n", cast(double)x);  // destroy scratch reg contents
    T y = a*a + a*a + a*a + a*a + a*a + a*a + a*a +
               a*b + a*b;
    assert(x == 11);
    assert(x == y);
}

void test240()
{
    testcse1!float();
    testcse1!double();
    testcse1!real();
}

/***************************************/

void testcse2(T)()  // common subexpressions
{
    T a = value_1();
    T b = value_2();
    T x = a*a + a*a + a*a + a*a + a*a + a*a + a*a +
               a*b + a*b + 1;
    printf("%g\n", cast(double)x);  // destroy scratch reg contents
    int i = (a*a + a*a + a*a + a*a + a*a + a*a + a*a + a*b + a*b) != 0;
    assert(i);
    assert(x == 12);
}

void test241()
{
    testcse2!float();
    testcse2!double();
    testcse2!real();
}

/***************************************/

int main()
{
    test240();
    test241();

    printf("Success\n");
    return EXIT_SUCCESS;
}
