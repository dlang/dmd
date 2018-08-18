/*
TEST_OUTPUT:
---
fail_compilation/aliasthis_scope.d(57): Error: there are many candidates to t.a resolve:
fail_compilation/aliasthis_scope.d(57):        (cast(ITest)t).getTest1().a
fail_compilation/aliasthis_scope.d(57):        (cast(ITest2)t).getTest2().a
fail_compilation/aliasthis_scope.d(57): Error: there are many candidates to t.a resolve:
fail_compilation/aliasthis_scope.d(57):        (cast(ITest)t).getTest1().a
fail_compilation/aliasthis_scope.d(57):        (cast(ITest2)t).getTest2().a
fail_compilation/aliasthis_scope.d(59): Error: undefined identifier `a`
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
    @property ref Test1 getTest1();
    alias getTest1 this;
}

interface ITest2
{
    @property ref Test2 getTest2();
    alias getTest2 this;
}

class Test: ITest, ITest2
{
    Test1 t1;
    Test2 t2;

    override @property ref Test1 getTest1()
    {
        return t1;
    }

    override @property ref Test2 getTest2()
    {
        return t2;
    }
}

void main()
{
    Test t = new Test();

    with(t)
    {
        long x = a;
    }
}
