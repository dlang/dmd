// https://issues.dlang.org/show_bug.cgi?id=15862

/*
PERMUTE_ARGS:
REQUIRED_ARGS: -O -release
*/


int* p() pure nothrow {return new int;}
int[] a() pure nothrow {return [0];}
Object o() pure nothrow {return new Object;}

immutable(int)* pn() pure nothrow {return new int;}
immutable(int)[] an() pure nothrow {return [0];}
immutable(Object) on() pure nothrow {return new Object;}

auto pa() pure nothrow {return new int;}
auto pb() pure nothrow {return cast(immutable(int)*)(new int);}

void main()
{
    {
        int* p1 = p();
        int* p2 = p();

        if (p1 is p2) assert(0);

        int[] a1 = a();
        int[] a2 = a();

        if (a1 is a2) assert(0);

        Object o1 = o();
        Object o2 = o();

        if (o1 is o2) assert(0);
    }
    {
        auto p1 = pn();
        auto p2 = pn();

        if (p1 !is p2) assert(0);

        auto a1 = an();
        auto a2 = an();

        if (a1 !is a2) assert(0);

        auto o1 = on();
        auto o2 = on();

        if (o1 !is o2) assert(0);
    }
    {
        auto p1 = pa();
        auto p2 = pa();

        if (p1 is p2) assert(0);
    }
    {
        auto p1 = pb();
        auto p2 = pb();

        if (p1 !is p2) assert(0);
    }
}
