
extern(C) int printf(const char*, ...);

extern(C) void _d_arrayliteralTX() { assert(0); }   // ArrayLiteralExp
extern(C) void _d_arraycatnTX() { assert(0); }      // CatExp: a ~ (b ~ c)
extern(C) void _d_arraycatT() { assert(0); }        // CatExp: a ~ b

/***********************/

@nogc int test1()
{
    return 3;
}

/***********************/
// 3032

void test3032() @nogc
{
    scope o1 = new Object();        // on stack
    scope o2 = new class Object {}; // on stack

    int n = 1;
    scope fp = (){ n = 10; };       // no closure
    fp();
    assert(n == 10);
}

/***********************/
// 12642

__gshared int[1] data12642;

int[1] foo12642() @nogc
{
    int x;
    return [x];
}

void test12642() @nogc
{
    int x;
    data12642 = [x];
    int[1] data2;
    data2 = [x];

    data2 = foo12642();
}

/***********************/
// 12751

void test12751() @nogc
{
    int[2] a1 = [1, 2];
    int[3] b1 = [4, 5, 6];
    int[6] c1 = a1 ~ 3 ~ b1;
    assert(c1 == [1, 2, 3, 4, 5, 6]);

    int[1] a2 = [1];
    int[2] b2 = [2, 3];
    int[3] c2 = a2 ~ b2;
    assert(c2 == [1, 2, 3]);

    int[3] sa0 = [1, 2, 3];
    int[] a = sa0[];

    int[4] sa1 = [1, 2] ~ [3, 4];
    assert(sa1 == [1, 2, 3, 4]);

    int[4] sa2 = a[0..2] ~ [3, 4];
    assert(sa2 == [1, 2, 3, 4]);

    int[4] sa3 = [1, 2] ~ a[1..3];
    assert(sa3 == [1, 2, 2, 3]);

    int[4] sa4 = a[1..3] ~ a[0..2];
    assert(sa4 == [2, 3, 1, 2]);

    int n = 4;
    int[7] sa5 = ((a[1..2] ~ n) ~ [5, 6]) ~ a[0..3];
    assert(sa5 == [2, 4, 5, 6, 1, 2, 3]);
}

void test12751b() @nogc
{
    void foo(size_t n)(int[n] a, int[n] b...)
    {
        assert(a == b);
    }

    int[3] a = [1,2,3];
    foo!3(a,           [1,2,3]);
    foo!6(a ~ a,       [1,2,3, 1,2,3]);
    foo!5(a[0..2] ~ a, [1,2, 1,2,3]);
    //foo(a[] * 3);     // missing destination memory
    // --> preFunctionParameters

    //void bar(int[3][2] a)
    //{
    //    assert(a == [[3,6,9], [4,8,12]]);
    //}
    //bar([a[] * 3, a[] * 4]);
}

/***********************/

int main()
{
    test1();
    test3032();
    test12642();
    test12751();

    printf("Success\n");
    return 0;
}
