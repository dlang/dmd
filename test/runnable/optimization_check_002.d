//Optimization check
import core.stdc.tgmath : fabs;
import std.algorithm : map, reduce;
import std.range : array, ElementType;
import std.conv : to;

F sumKBN(Range, F = ElementType!Range)(Range r)
{
    F s = 0.0;
    F c = 0.0;
    foreach(F x; r)
    {
        F t = s + x;
        if(s.fabs >= x.fabs)
            c += (s-t)+x;
        else
            c += (x-t)+s;
        s = t;
    }

    return s + c;
}

void test0() 
{
    double[] ar = [1.0*10000, 1e100*10000, 1*10000, -1e100*10000];
    double r = 2*10000;
    assert(r != ar.reduce!"a+b");
    assert(r == ar.sumKBN, "ar.sumKBN = "~ar.sumKBN.to!string);
}

void test1() 
{
    auto ar = [1.0, 1e100, 1, -1e100].map!(a => a*10000)();
    double r = 2*10000;
    assert(r != ar.reduce!"a+b");
    assert(r == ar.sumKBN, "ar.sumKBN = "~ar.sumKBN.to!string);
}

void main() {
    test0();
    test1();
    import core.stdc.stdio;
    printf("Success\n");
}
