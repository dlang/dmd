/*
TEST_OUTPUT:
---
fail_compilation/aliasthis_static_init.d(44): Error: unable to represent Test as initializer; candidates:
fail_compilation/aliasthis_static_init.d(44):        (cast(ITest)(Test) , getTest1)()
fail_compilation/aliasthis_static_init.d(44):        (cast(ITest2)(Test) , getTest2)()
---
*/

struct Test1
{
    int a;
}

struct Test2
{
    short a;
}

interface ITest
{
    static @property Test1 getTest1()
    {
        return Test1();
    }
    static alias getTest1 this;
}

interface ITest2
{
    static @property Test2 getTest2()
    {
        return Test2();
    }
    static alias getTest2 this;
}

class Test: ITest, ITest2
{
}

void main()
{
    auto x = Test;
}
