module ufcs;

extern (C) int printf(const char*, ...);

/*******************************************/
// 662

import std.stdio,std.string, std.conv;

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
// 3382

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

void main()
{
    test682();
    test3382();
}
