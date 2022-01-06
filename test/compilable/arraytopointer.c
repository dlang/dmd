
/* Test conversion of expressions:
 *    array of T => pointer to T
 *    function => pointer to function
 */

int func(int *);
int burg(int (*fp)());
int clog();

void testFunctionArguments()
{
    int a[3];
    func(a);

    int b[] = { 0 };
    func(b);

    burg(clog);
}

void testIndexing()
{
    int a[3];
    a[0] = 1;
}

void testAdd()
{
    int a[3];
    int* p = a + 1;
    p = 1 + 1;
}

void testMin()
{
    int a[3];
    int* p = a - 1;
}

void testCond()
{
    int i;
    int a[3];
    int b[3];
    int* p = i ? a : b;
}

int testIndexing2()
{
    int *p;
    int i = p[1];
    i = 2[p];
}

void testAssign()
{
    int a[3];
    int *p = a;
}

void testComma()
{
    int a[3];
    int* p = (1, a) + 1;
    _Static_assert(sizeof((1, a)) == sizeof(int*), "testComma");
}

int testArrow()
{
    struct S { int m, n; };

    struct S a[3];
    return a->m;
}



