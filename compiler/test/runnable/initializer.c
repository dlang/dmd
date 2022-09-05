/* Test initializers */

int printf(const char *s, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test %d\n", line);
        exit(1);
    }
}

/*******************************************/

void test1()
{
    static int a1[] = { 1, 2, [0] = 3 };

    assert(a1[0] == 3, __LINE__);
    assert(a1[1] == 2, __LINE__);
    assert(sizeof(a1) == 8, __LINE__);
}

/*******************************************/

int a2[2][3] = { 1,2,[1]={3} };

void test2()
{
    assert(a2[0][0] == 1, __LINE__);
    assert(a2[0][1] == 2, __LINE__);
    assert(a2[0][2] == 0, __LINE__);
    assert(a2[1][0] == 3, __LINE__);
    assert(a2[1][1] == 0, __LINE__);
    assert(a2[1][2] == 0, __LINE__);
}

/*******************************************/

int a3[2][3] = { 1,2,3,[1]=4 };

void test3()
{
    assert(a3[0][0] == 1, __LINE__);
    assert(a3[0][1] == 2, __LINE__);
    assert(a3[0][2] == 3, __LINE__);
    assert(a3[1][0] == 4, __LINE__);
    assert(a3[1][1] == 0, __LINE__);
    assert(a3[1][2] == 0, __LINE__);
}

/*******************************************/

typedef struct S { int a, b; } S;
S a4[2] = { 3, 4, 5, 6 };

void test4()
{
    assert(a4[0].a == 3, __LINE__);
    assert(a4[0].b == 4, __LINE__);
    assert(a4[1].a == 5, __LINE__);
    assert(a4[1].b == 6, __LINE__);
}

/*******************************************/

int y5[4][3] = {
    {1,3,5},
    {2,4,6},
    {3,5,7},
};

void test5()
{
    assert(y5[0][0] == 1, __LINE__);
    assert(y5[0][1] == 3, __LINE__);
    assert(y5[0][2] == 5, __LINE__);
    assert(y5[1][0] == 2, __LINE__);
    assert(y5[1][1] == 4, __LINE__);
    assert(y5[1][2] == 6, __LINE__);
    assert(y5[2][0] == 3, __LINE__);
    assert(y5[2][1] == 5, __LINE__);
    assert(y5[2][2] == 7, __LINE__);
    assert(y5[3][0] == 0, __LINE__);
    assert(y5[3][1] == 0, __LINE__);
    assert(y5[3][2] == 0, __LINE__);
}

/*******************************************/

int y6[4][3] = {
    1,3,5,
    2,4,6,
    3,5,7
};

void test6()
{
    assert(y6[0][0] == 1, __LINE__);
    assert(y6[0][1] == 3, __LINE__);
    assert(y6[0][2] == 5, __LINE__);
    assert(y6[1][0] == 2, __LINE__);
    assert(y6[1][1] == 4, __LINE__);
    assert(y6[1][2] == 6, __LINE__);
    assert(y6[2][0] == 3, __LINE__);
    assert(y6[2][1] == 5, __LINE__);
    assert(y6[2][2] == 7, __LINE__);
    assert(y6[3][0] == 0, __LINE__);
    assert(y6[3][1] == 0, __LINE__);
    assert(y6[3][2] == 0, __LINE__);
}

/*******************************************/

int y7[4][3] = {
    {1},{2},{3},{4}
};

void test7()
{
    assert(y7[0][0] == 1, __LINE__);
    assert(y7[0][1] == 0, __LINE__);
    assert(y7[0][2] == 0, __LINE__);
    assert(y7[1][0] == 2, __LINE__);
    assert(y7[1][1] == 0, __LINE__);
    assert(y7[1][2] == 0, __LINE__);
    assert(y7[2][0] == 3, __LINE__);
    assert(y7[2][1] == 0, __LINE__);
    assert(y7[2][2] == 0, __LINE__);
    assert(y7[3][0] == 4, __LINE__);
    assert(y7[3][1] == 0, __LINE__);
    assert(y7[3][2] == 0, __LINE__);
}

/*******************************************/

int q8[4][3][2] = {
    {1},
    {2,3},
    {4,5,6}
};

void test8()
{
    assert(q8[0][0][0] == 1, __LINE__);
    assert(q8[0][0][1] == 0, __LINE__);
    assert(q8[0][1][0] == 0, __LINE__);
    assert(q8[0][1][1] == 0, __LINE__);
    assert(q8[0][2][0] == 0, __LINE__);
    assert(q8[0][2][1] == 0, __LINE__);

    assert(q8[1][0][0] == 2, __LINE__);
    assert(q8[1][0][1] == 3, __LINE__);
    assert(q8[1][1][0] == 0, __LINE__);
    assert(q8[1][1][1] == 0, __LINE__);
    assert(q8[1][2][0] == 0, __LINE__);
    assert(q8[1][2][1] == 0, __LINE__);

    assert(q8[2][0][0] == 4, __LINE__);
    assert(q8[2][0][1] == 5, __LINE__);
    assert(q8[2][1][0] == 6, __LINE__);
    assert(q8[2][1][1] == 0, __LINE__);
    assert(q8[2][2][0] == 0, __LINE__);
    assert(q8[2][2][1] == 0, __LINE__);

    assert(q8[3][0][0] == 0, __LINE__);
    assert(q8[3][0][1] == 0, __LINE__);
    assert(q8[3][1][0] == 0, __LINE__);
    assert(q8[3][1][1] == 0, __LINE__);
    assert(q8[3][2][0] == 0, __LINE__);
    assert(q8[3][2][1] == 0, __LINE__);
}

/*******************************************/

int q9[4][3][2] = {
    1, 0, 0, 0, 0, 0,
    2, 3, 0, 0, 0, 0,
    4, 5, 6
};

void test9()
{
    assert(q9[0][0][0] == 1, __LINE__);
    assert(q9[0][0][1] == 0, __LINE__);
    assert(q9[0][1][0] == 0, __LINE__);
    assert(q9[0][1][1] == 0, __LINE__);
    assert(q9[0][2][0] == 0, __LINE__);
    assert(q9[0][2][1] == 0, __LINE__);

    assert(q9[1][0][0] == 2, __LINE__);
    assert(q9[1][0][1] == 3, __LINE__);
    assert(q9[1][1][0] == 0, __LINE__);
    assert(q9[1][1][1] == 0, __LINE__);
    assert(q9[1][2][0] == 0, __LINE__);
    assert(q9[1][2][1] == 0, __LINE__);

    assert(q9[2][0][0] == 4, __LINE__);
    assert(q9[2][0][1] == 5, __LINE__);
    assert(q9[2][1][0] == 6, __LINE__);
    assert(q9[2][1][1] == 0, __LINE__);
    assert(q9[2][2][0] == 0, __LINE__);
    assert(q9[2][2][1] == 0, __LINE__);

    assert(q9[3][0][0] == 0, __LINE__);
    assert(q9[3][0][1] == 0, __LINE__);
    assert(q9[3][1][0] == 0, __LINE__);
    assert(q9[3][1][1] == 0, __LINE__);
    assert(q9[3][2][0] == 0, __LINE__);
    assert(q9[3][2][1] == 0, __LINE__);
}

/*******************************************/

int q10[4][3][2] = {
    {
      { 1 },
    },
    {
      { 2, 3 },
    },
    {
      { 4, 5 },
      { 6 },
    }
};

void test10()
{
    assert(q10[0][0][0] == 1, __LINE__);
    assert(q10[0][0][1] == 0, __LINE__);
    assert(q10[0][1][0] == 0, __LINE__);
    assert(q10[0][1][1] == 0, __LINE__);
    assert(q10[0][2][0] == 0, __LINE__);
    assert(q10[0][2][1] == 0, __LINE__);

    assert(q10[1][0][0] == 2, __LINE__);
    assert(q10[1][0][1] == 3, __LINE__);
    assert(q10[1][1][0] == 0, __LINE__);
    assert(q10[1][1][1] == 0, __LINE__);
    assert(q10[1][2][0] == 0, __LINE__);
    assert(q10[1][2][1] == 0, __LINE__);

    assert(q10[2][0][0] == 4, __LINE__);
    assert(q10[2][0][1] == 5, __LINE__);
    assert(q10[2][1][0] == 6, __LINE__);
    assert(q10[2][1][1] == 0, __LINE__);
    assert(q10[2][2][0] == 0, __LINE__);
    assert(q10[2][2][1] == 0, __LINE__);

    assert(q10[3][0][0] == 0, __LINE__);
    assert(q10[3][0][1] == 0, __LINE__);
    assert(q10[3][1][0] == 0, __LINE__);
    assert(q10[3][1][1] == 0, __LINE__);
    assert(q10[3][2][0] == 0, __LINE__);
    assert(q10[3][2][1] == 0, __LINE__);
}

/*******************************************/

typedef int A[];
A a = { 1, 2 }, b = { 3, 4, 5 };
_Static_assert(sizeof(a) == 8, "1");
_Static_assert(sizeof(b) == 12, "2");

/*******************************************/

int a11[10] = {
    1,2,3, [6] = 4,5,6
};

void test11()
{
    assert(a11[0] == 1, __LINE__);
    assert(a11[1] == 2, __LINE__);
    assert(a11[2] == 3, __LINE__);
    assert(a11[3] == 0, __LINE__);
    assert(a11[4] == 0, __LINE__);
    assert(a11[5] == 0, __LINE__);
    assert(a11[6] == 4, __LINE__);
    assert(a11[7] == 5, __LINE__);
    assert(a11[8] == 6, __LINE__);
    assert(a11[9] == 0, __LINE__);
}

/*******************************************/

char s12[] = "hello";

void test12()
{
    assert(sizeof(s12) == 6, __LINE__);
    assert(s12[4] == 'o', __LINE__);
    assert(s12[5] == 0, __LINE__);
}

/*******************************************/

char s13[6] = "hello";

void test13()
{
    assert(sizeof(s13) == 6, __LINE__);
    assert(s13[4] == 'o', __LINE__);
    assert(s13[5] == 0, __LINE__);
}

/*******************************************/

char s14[5] = "hello";

void test14()
{
    assert(sizeof(s14) == 5, __LINE__);
    assert(s14[4] == 'o', __LINE__);
}

/*******************************************/

char s15[5] = { "hello" };

void test15()
{
    assert(sizeof(s15) == 5, __LINE__);
    assert(s15[4] == 'o', __LINE__);
}

/*******************************************/

char s16[2][6] = { "hello", "world" };

void test16()
{
    assert(sizeof(s16) == 12, __LINE__);
    assert(s16[1][2] == 'r', __LINE__);
}

/*******************************************/

char s17[2][6] = { {"hello"}, {"world"} };

void test17()
{
    assert(sizeof(s17) == 12, __LINE__);
    assert(s17[1][2] == 'r', __LINE__);
}

/*******************************************/

char s18[2][1][6] = { "hello", "world" };

void test18()
{
    assert(sizeof(s18) == 12, __LINE__);
    assert(s18[1][0][2] == 'r', __LINE__);
}

/*******************************************/

struct S19 { int a, b; };

struct S19 a19[1] = { 1 };

void test19()
{
    assert(a19[0].a == 1, __LINE__);
    assert(a19[0].b == 0, __LINE__);
}

/*******************************************/

struct S20 { int a, b; };

struct S20 a20[1] = { 1, [0] = 2 };

void test20()
{
    assert(a20[0].a == 2, __LINE__);
    assert(a20[0].b == 0, __LINE__);
}

/*******************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    test12();
    test13();
    test14();
    test15();
    test16();
    test17();
    test18();
    test19();
    test20();

    return 0;
}
