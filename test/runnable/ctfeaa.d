import core.stdc.stdio;

__gshared int[int] t1 = [1 : 2, 3 : 4];

void test1()
{
    assert(t1[1] == 2);
    assert(t1[3] == 4);
    assert(t1.length == 2);

    t1[3] = -1;
    t1[5] = 6;
    assert(t1 == [1 : 2, 3 : -1, 5 : 6]);
}

__gshared string[string] t2 = ["1" : "2", "3" : "4"];

void test2()
{
    assert(t2["1"] == "2");
    assert(t2["3"] == "4");
    assert(t2.length == 2);

    t2["3"] = "-1";
    t2["5"] = "6";
    assert(t2 == ["1" : "2", "3" : "-1", "5" : "6"]);
}

__gshared real[real] t3 = [1.0 : 2.5, 3.2 : 4.3];

void test3()
{
    assert(t3[1.0] == 2.5);
    assert(t3[3.2] == 4.3);
    assert(t3.length == 2);

    t3[3.2] = 2.7;
    t3[5.7] = 6.4;
    assert(t3 == [1.0L : 2.5L, 3.2 : 2.7, 5.7 : 6.4]);
}

struct Test4
{
    int a;
    size_t toHash() const
    {
        return a;
    }
}

__gshared int[Test4] t4 = [Test4(1) : 2, Test4(3) : 4];

void test4()
{
    assert(t4[Test4(1)] == 2);
    assert(t4[Test4(3)] == 4);
    assert(t4.length == 2);

    t4[Test4(3)] = -1;
    t4[Test4(5)] = 6;
    assert(t4 == [Test4(1) : 2, Test4(3) : -1, Test4(5) : 6]);
}

struct Test5
{
    int a;
}

__gshared int[Test5] t5 = [Test5(1) : 2, Test5(3) : 4];

void test5()
{
    assert(t5[Test5(1)] == 2);
    assert(t5[Test5(3)] == 4);
    assert(t5.length == 2);

    t5[Test5(3)] = -1;
    t5[Test5(5)] = 6;
    assert(t5 == [Test5(1) : 2, Test5(3) : -1, Test5(5) : 6]);
}


__gshared int[int[]] t6 = [[1, 2] : 2, [3, 4] : 4];

void test6()
{
    assert(t6[[1, 2]] == 2);
    assert(t6[[3, 4]] == 4);
    assert(t6.length == 2);

    t6[[3, 4].idup] = -1;
    t6[[5, 6].idup] = 6;
    assert(t6 == [[1, 2] : 2, [3, 4] : -1, [5, 6] : 6]);
}

class Test7
{
    int a;

    this(int a)
    {
        this.a = a;
    }

    override size_t toHash() const
    {
        return a;
    }

    override bool opEquals(Object rvl)
    {
        if (auto r = cast(Test7)rvl)
        {
            return a == r.a;
        }
        return false;
    }
}

__gshared int[Test7] t7 = [new Test7(1) : 2, new Test7(3) : 4];

void test7()
{
    assert(t7[new Test7(1)] == 2);
    assert(t7[new Test7(3)] == 4);
    assert(t7.length == 2);

    t7[new Test7(3)] = -1;
    t7[new Test7(5)] = 6;
    assert(t7 == [new Test7(1) : 2, new Test7(3) : -1, new Test7(5) : 6]);
}

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    printf("Success!\n");
}
