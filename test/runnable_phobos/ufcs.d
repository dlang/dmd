module ufcs;

extern (C) int printf(const char*, ...);

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=662

import std.string, std.conv;

enum Etest
{
    a,b,c,d
}

//typedef int testi = 10;
//typedef Test Test2;

int test() { return 33; }

class Test
{
    static int test(int i) { return i; }
}

int test(Etest test)
{
    return cast(int)test;
}

//int test(testi i)
//{
//  return cast(int)i;
//}

void test682()
{
    assert(22.to!string() == "22");
    assert((new Test).test(11) == 11);
    assert(Test.test(11) == 11);
    //assert(Test2.test(11) == 11);
    assert(test() == 33);
    assert(ufcs.test() == 33);
    assert(Etest.d.test() == Etest.d);
    //testi i;
    //assert(i.test() == i.init);
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=3382

import std.range, std.algorithm;

@property T twice(T)(T x){ return x * x; }
real toreal(ireal x){ return x.im; }
char toupper(char c){ return ('a'<=c && c<='z') ? cast(char)(c - 'a' + 'A') : c; }

@property ref T setter(T)(ref T x, T v){ x = v; return x; }

void test3382()
{
    auto r = iota(0, 10).map!"a*3"().filter!"a%2 != 0"();
    foreach (e; r)
        printf("e = %d\n", e);

    assert(10.twice == 100);
    assert(0.5.twice == 0.25);
    assert(1.4i.toreal() == 1.4);
    assert('c'.toupper() == 'C');
}

/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=6185

void test6185()
{
    import std.algorithm;

    auto r1 = [1,2,3].map!"a*2";
    assert(equal(r1, [2,4,6]));

    auto r2 = r1.map!"a+2"();
    assert(equal(r2, [4,6,8]));
}

/*******************************************/

int main()
{
    test682();
    test3382();
    test6185();

    printf("Success\n");
    return 0;
}
