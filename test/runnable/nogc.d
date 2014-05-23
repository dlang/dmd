
extern(C) int printf(const char*, ...);

/***********************/

@nogc int test1()
{
    return 3;
}

@nogc void test2()
{
    if(__ctfe)
    {
        int[] arr;
        arr ~= 42;
    }
}

@nogc void test3()
{
    if(!__ctfe)
    {
    }
    else
    {
        int[] arr;
        arr ~= 42;
    }
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
    test2();
    test3();
    test12642();

    printf("Success\n");
    return 0;
}
