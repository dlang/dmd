/*
TEST_OUTPUT:
---
fail_compilation/aliasthis_switch.d(42): Error: unable to represent t as switch condition; candidates:
fail_compilation/aliasthis_switch.d(42):        (cast(ITest)t).getInt()
fail_compilation/aliasthis_switch.d(42):        (cast(ITest2)t).getChar()
---
*/

interface ITest
{
    @property ref int getInt();
    alias getInt this;
}

interface ITest2
{
    @property ref char getChar();
    alias getChar this;
}

class Test: ITest, ITest2
{
    int a;
    char b;

    override @property ref int getInt()
    {
        return a;
    }

    override @property ref char getChar()
    {
        return b;
    }
}

void main()
{
    Test t = new Test();

    switch (t)
    {
        default:
            break;
    }
}
