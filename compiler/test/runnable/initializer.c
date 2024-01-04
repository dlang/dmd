/* Test initializers */

int printf(const char *s, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test at line %d\n", line);
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

/* https://issues.dlang.org/show_bug.cgi?id=22994
 */

char cs1[1];
double ds1[1];
char cs[2] = {0};
double ds[2] = {0.0};
struct { char cs[2]; } css = { {0} };
struct { double ds[2]; } dss = { {0} };
union { char cs[2]; } csu = { {0} };
union { double ds[2]; } dsu = { {0} };

void test22994()
{
    if (0)
    {
        printf("%d\n", (int)cs1[0]);
        printf("%lf\n", ds1[0]);
        printf("%d\n", (int)cs[1]);
        printf("%lf\n", ds[1]);
        printf("%d\n", (int)css.cs[1]);
        printf("%lf\n", dss.ds[1]);
        printf("%d\n", (int)csu.cs[1]);
        printf("%lf\n", dsu.ds[1]);
        printf("%d\n", (int)((char[2]){0})[1]);
        printf("%lf\n", ((double[2]){0})[1]);
    }

    assert(cs1[0]== 0, __LINE__);
    assert(ds1[0]== 0, __LINE__);
    assert(cs[1]== 0, __LINE__);
    assert(ds[1]== 0, __LINE__);
    assert(css.cs[1]== 0, __LINE__);
    assert(dss.ds[1]== 0, __LINE__);
    assert(csu.cs[1]== 0, __LINE__);
    assert(dsu.ds[1]== 0, __LINE__);
    assert(((char[2]){0})[1]== 0, __LINE__);
    assert(((double[2]){0})[1]== 0, __LINE__);
}

/*******************************************/


void test31()
{
    static int a[3] = {1, 2, 3};
    if (a[0] != 1 ||
        a[1] != 2 ||
        a[2] != 3)
    {
        assert(0, __LINE__);
    }
}

/*********************************/

void test32()
{
    static int a[4] = {1, 2, 3};
    if (a[0] != 1 ||
        a[1] != 2 ||
        a[2] != 3 ||
        a[3] != 0)
    {
        assert(0, __LINE__);
    }
}

/*********************************/

void test33()
{
    static int a[] = {1, 2, 3};
    if (sizeof(a) != 3 * sizeof(int) ||
        a[0] != 1 ||
        a[1] != 2 ||
        a[2] != 3)
    {
        assert(0, __LINE__);
    }
}

/*********************************/

void test34()
{
    static int a[3] = {1, 2, 3};
    int i;
    for (i = 0; i < 3; ++i)
    {
        if (a[i] != i + 1)
        {
            assert(0, __LINE__);
        }
    }
}

/*********************************/

void test35()
{
    static int b[3][2] = { 1,2,3,4,5,6 };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (b[i][j] != i * 2 + j + 1)
            {
                assert(0, __LINE__);
            }
        }
    }
}

/*********************************/

void test36()
{
    static int c[3][2] = { {1,2},{3,4},{5,6} };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (c[i][j] != i * 2 + j + 1)
            {
                assert(0, __LINE__);
            }
        }
    }
}

/*********************************/

void test37()
{
    static int d[3][2] = { {1,2},3,4,{5,6} };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (d[i][j] != i * 2 + j + 1)
            {
                assert(0, __LINE__);
            }
        }
    }
}

/*********************************/

void test23007()
{
    static int x[1] = {{1}};
    assert(x[0] == 1, __LINE__);
}

/*********************************/

void test38()
{
    static int d[3][2] = { {1,2} };
    int i;
    for (i = 0; i < 3; ++i)
    {
        int j;
        for (j = 0; j < 2; ++j)
        {
            if (i == 0)
            {
                if (d[i][j] != j + 1)
                {
                    assert(0, __LINE__);
                }
            }
            else if (d[i][j] != 0)
            {
                assert(0, __LINE__);
            }
        }
    }
}

/*********************************/

void test38a()
{
    int i;
    static int a[3] = { 1,2,3 };
    // Casting to an array type is not allowed by C11, but
    // CompoundLiterals are not there yet to test this
    // grammar
    i = ((int[3])a)[2];
    assert(i == 3, __LINE__);
}

/*********************************/

void test38b()
{
    struct S { int a, b; };
    static struct S ax[3] = { 0x11,0x22,0x33,0 };
    //printf("%x %x %x %x %x %x\n", ax[0].a, ax[0].b, ax[1].a, ax[1].b, ax[2].a, ax[2].b);
    if (ax[0].a != 0x11 ||
        ax[0].b != 0x22 ||
        ax[1].a != 0x33 ||
        ax[1].b != 0 ||
        ax[2].a != 0 ||
        ax[2].b != 0) { assert(0, __LINE__); }
    static struct S ay[3] = { {0x11,0x22},0x33,0 };
    //printf("%x %x %x %x %x %x\n", ay[0].a, ay[0].b, ay[1].a, ay[1].b, ay[2].a, ay[2].b);
    if (ay[0].a != 0x11 ||
        ay[0].b != 0x22 ||
        ay[1].a != 0x33 ||
        ay[1].b != 0 ||
        ay[2].a != 0 ||
        ay[2].b != 0) { assert(0, __LINE__); }
    static struct S az[3] = { 0x11,0x22,{0x33,0} };
    //printf("%x %x %x %x %x %x\n", az[0].a, az[0].b, az[1].a, az[1].b, az[2].a, az[2].b);
    if (az[0].a != 0x11 ||
        az[0].b != 0x22 ||
        az[1].a != 0x33 ||
        az[1].b != 0 ||
        az[2].a != 0 ||
        az[2].b != 0) { assert(0, __LINE__); }
}

/*********************************/

void test23006()
{
    static struct { int x[1][1]; } y = { {{1}} };
    assert(y.x[0][0] == 1, __LINE__);
}

/*********************************/

void test39()
{
    int i = 1;            assert(i == 1, __LINE__);
    int j = { 2 };        assert(j == 2, __LINE__);
    int k = { 3,};        assert(k == 3, __LINE__);

    static int l = 4;     assert(l == 4, __LINE__);
    static int m = { 5 }; assert(m == 5, __LINE__);
    static int n = { 6,}; assert(n == 6, __LINE__);
}

/*********************************/

void test22610()
{
    struct S
    {
        unsigned char c[4];
    };
    static struct S c = { 255,255,255,255 };
    assert(c.c[0] == 255, __LINE__);
    assert(c.c[1] == 255, __LINE__);
    assert(c.c[2] == 255, __LINE__);
    assert(c.c[3] == 255, __LINE__);
}

/*********************************/

void test40()
{
    char s[6] = { "s" }; if (s[0] != 's')                     { assert(0, __LINE__); }
    char t[7] = { "t" }; if (t[0] != 't' && t[1] != 0)        { assert(0, __LINE__); }
    static char u[6] = { "u" }; if (u[0] != 'u')              { assert(0, __LINE__); }
    static char v[7] = { "v" }; if (v[0] != 'v' && v[1] != 0) { assert(0, __LINE__); }
}

/*********************************/

void test41()
{
    struct S { int a, b; };
    struct S s = { 1, 2 };
    if (s.a != 1 || s.b != 2) { assert(0, __LINE__); }
    static struct S s2 = { 1, };
    if (s2.a != 1 || s2.b != 0) { assert(0, __LINE__); }

    struct T { int a; struct { int b, c; }; };
    struct T t = { 1, 2, 3 };
    if (t.a != 1 || t.b != 2 || t.c != 3) { assert(0, __LINE__); }

    struct U { int a; union { int b, c; }; int d; };
    struct U u = { 1, 2, 3 };
    if (u.a != 1 ||
        u.b != 2 ||
        u.c != 2 ||
        u.d != 3) { printf("%d %d %d %d\n", u.a, u.b, u.c, u.d); assert(0, __LINE__); }
}

/*********************************/

void test23230()
{
    static char scharkey[4][17] =
    {
        "define",
        "list",
        "if",
        "lambda"
    };
    assert(scharkey[0][3] == 'i', __LINE__);
    assert(scharkey[1][2] == 's', __LINE__);
    assert(scharkey[2][1] == 'f', __LINE__);
    assert(scharkey[3][0] == 'l', __LINE__);
}

/*********************************/
// https://issues.dlang.org/show_bug.cgi?id=22652

void test22652()
{
    struct S1 {
        int x, y;
    };

    struct S2 {
        struct S1 s;
    };

    struct S2 c = {1};
    struct S2 d = {1, 2};

    assert(c.s.x == 1, __LINE__);
    assert(c.s.y == 0, __LINE__);
    assert(d.s.x == 1, __LINE__);
    assert(d.s.y == 2, __LINE__);
}

/*********************************/

void test42()
{
    int i;
    i = (int) { 3 };
    assert(i == 3, __LINE__);
}

/*******************************************/

void test43()
{
    static int a[2] = { [0] = 1, [1] = 2, };
    assert(a[0] == 1, __LINE__);
    assert(a[1] == 2, __LINE__);

    typedef struct S { int x; } S;
    S s = {.x = 3};
    assert(s.x == 3, __LINE__);
}


/*******************************************/
// 23027

struct S44 {
    int x;
};

void test44()
{
    struct S44 s[2] = {3};
    assert(s[0].x == 3, __LINE__);
    assert(s[1].x == 0, __LINE__);
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=23338

struct S45 {
    char a, b[2];
};

struct S45 s45 = { 1, 2, 3 };
struct S45 t45 = { 'a', "bc" };

void test45()
{
    assert(s45.a    == 1, __LINE__);
    assert(s45.b[0] == 2, __LINE__);
    assert(s45.b[1] == 3, __LINE__);
    assert(t45.a    == 'a', __LINE__);
    assert(t45.b[0] == 'b', __LINE__);
    assert(t45.b[1] == 'c', __LINE__);
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=23348

struct SS46 {
    char a, b[2];
};

struct S46 {
    struct SS46 ss;
    char d;
};

static struct S46 s46 = { 1, 2, 3, 4 };
static struct S46 t46 = { 'a', "bc", 'd' };

void test46()
{
    assert(s46.ss.a    == 1, __LINE__);
    assert(s46.ss.b[0] == 2, __LINE__);
    assert(s46.ss.b[1] == 3, __LINE__);
    assert(s46.d       == 4, __LINE__);
    assert(t46.ss.a    == 'a', __LINE__);
    assert(t46.ss.b[0] == 'b', __LINE__);
    assert(t46.ss.b[1] == 'c', __LINE__);
    assert(t46.d       == 'd', __LINE__);
}

/*******************************************/

void test22925()
{
    int arr[1][1] = { {1} };
    assert(arr[0][0] == 1, __LINE__);
}

/*******************************************/

// https://issues.dlang.org/show_bug.cgi?id=23345

struct S47 { int a, b; };

struct S47 s47 = { .b = 3, .a = 2 };

void test47()
{
    assert(s47.b == 3, __LINE__);
    assert(s47.a == 2, __LINE__);
}

/*******************************************/

// https://issues.dlang.org/show_bug.cgi?id=24154

void test24154()
{
    int x = ({
	int ret;
	ret = 3;
	ret;
    });
    assert(x == 3, __LINE__);
}

/*******************************************/

// https://issues.dlang.org/show_bug.cgi?id=24155

struct S24155 { int x, y; };

struct S24155 s = { };

void abc(int i)
{
    assert(s.x == 0 && s.y == 0, __LINE__);
    struct S24155 s1 = { };
    assert(s1.x == 0 && s1.y == 0, __LINE__);
    struct S24155 s2 = { { i }, { } };
    assert(s2.x == i && s2.y == 0, __LINE__);
    struct S24155 s3 = { { }, { i } };
    assert(s3.x == 0 && s3.y == i, __LINE__);
}

void test24155()
{
    abc(1);
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
    test22994();
    test31();
    test32();
    test33();
    test34();
    test35();
    test36();
    test37();
    test23007();
    test38();
    test38a();
    test38b();
    test23006();
    test39();
    test22610();
    test40();
    test41();
    test23230();
    test22652();
    test42();
    test43();
    test44();
    test45();
    test46();
    test22925();
    test47();
    test24154();
    test24155();

    return 0;
}
