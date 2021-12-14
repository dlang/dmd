// https://issues.dlang.org/show_bug.cgi?id=22428

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

/*********************************************/

static void dummy() { } // so staticFunc() isn't at offset 0

static int staticFunc(int i) { return i * 2; }

void testStaticFunc()
{
    int x = staticFunc(3);
    printf("%d\n", x);
    assert(x == 6, 20);

    int (*fp)(int);
    fp = &staticFunc;
    x = (*fp)(5);
    printf("%d\n", x);
    assert(x == 10, 21);
}

/*********************************************/

static int staticVar;
static int staticVar1 = 1;

void statics()
{
    assert(staticVar == 0, 0);
    assert(staticVar1 == 1, 1);
    static int staticVar = 2;
    assert(staticVar == 2, 2);
    {
        static int staticVar2 = 3;
        assert(staticVar2 == 3, 3);
    }
    {
        static int staticVar2 = 4;
        assert(staticVar2 == 4, 4);
    }
}

static int* pstatic = &staticVar1;

void pointers()
{
    int *p = &staticVar;
    assert(*p == 0, 10);
    p = &staticVar1;
    assert(*p == 1, 11);
    assert(*pstatic == 1, 12);
}

int main()
{
    testStaticFunc();
    statics();
    pointers();
    return 0;
}

