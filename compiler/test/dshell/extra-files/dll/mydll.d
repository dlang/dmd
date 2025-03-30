module mydll;

export:

__gshared int saved_var;

int multiply10(int x)
{
    saved_var = x;

    return x * 10;
}

struct S
{
    int i;

    export int add(int j)
    {
        return i += j;
    }
}

// https://issues.dlang.org/show_bug.cgi?id=9729
interface I9729
{
    C9729 foo(I9729);

    export static C9729 create()
    {
        return new C9729();
    }
}

class C9729 : I9729
{
    int x, y;

    export C9729 foo(I9729 i)
    {
        return cast(C9729) i;
    }
}

// https://issues.dlang.org/show_bug.cgi?id=10462
void call10462(int delegate() dg)
{
    assert(dg() == 7);
}

interface I10462
{
    int opCall();
}

class C10462 : I10462
{
    int opCall() { return 7; }
}

void test10462_dll()
{
    I10462 i = new C10462;
    call10462(&i.opCall);
}

// https://issues.dlang.org/show_bug.cgi?id=19660
extern (C)
{
    __gshared int someValue19660 = 0xF1234;
    void setSomeValue19660(int v)
    {
        someValue19660 = v;
    }
    int getSomeValue19660()
    {
        return someValue19660;
    }
}

extern (C++)
{
    __gshared int someValueCPP19660 = 0xF1234;
    void setSomeValueCPP19660(int v)
    {
        someValueCPP19660 = v;
    }
    int getSomeValueCPP19660()
    {
        return someValueCPP19660;
    }
}
