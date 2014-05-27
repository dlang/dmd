
extern(C) int printf(const char*, ...);

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

int main()
{
    test1();
    test3032();
    test12642();

    printf("Success\n");
    return 0;
}
