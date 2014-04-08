
import std.stdio;

/***********************************/

template cat1(T)
{
     T cat1(T i) { return i + 1; }
}

void test1()
{
    auto a = cat1(1);
    assert(a == 2);
}

/***********************************/

template cat2(T)
{
     T cat2(T* p) { return *p + 1; }
}

void test2()
{
    int i = 1;
    auto a = cat2(&i);
    assert(a == 2);
    assert(typeid(typeof(a)) == typeid(int));
}

/***********************************/

struct S3 { }

template cat3(T)
{
     T cat3(T* p, S3 s) { return *p + 1; }
}

void test3()
{
    S3 s;
    int i = 1;
    auto a = cat3(&i, s);
    assert(a == 2);
    assert(typeid(typeof(a)) == typeid(int));
}

/***********************************/

template cat4(T, int N)
{
     T cat4(T[N] p, T[N] q) { return p[0] + N; }
}

void test4()
{
    int[3] i;
    i[0] = 7;
    i[1] = 8;
    i[2] = 9;
    auto a = cat4(i, i);
    assert(a == 10);
    assert(typeid(typeof(a)) == typeid(int));
}

/***********************************/

template cat5(T, U=T*, int V=7)
{
     T cat5(T x)
     {	U u = &x;

	return x + 3 + *u + V;
     }
}

void test5()
{
    int x = 2;

    auto a = cat5(x);
    assert(a == 14);
    assert(typeid(typeof(a)) == typeid(int));

    auto b = cat5!(int,int*,8)(x);
    assert(b == 15);
    assert(typeid(typeof(b)) == typeid(int));

}

/***********************************/

int* pureMaker() pure
{
    return [1,2,3,4].ptr + 1;
}

void testDIP29_1()
{
    int* p;
    //immutable x = p + 3;
    immutable x = pureMaker() + 1;
    immutable y = pureMaker() - 1;
    immutable z = 1 + pureMaker();
}

/***********************************/

int** pureMaker2() pure
{
    int*[] da = [[11,12,13].ptr, [21,22,23].ptr, [31,32,33].ptr, [41,42,43].ptr];
    return da.ptr + 1;
}

void testDIP29_2()
{
    immutable x2 = pureMaker2() + 1;
    immutable y2 = pureMaker2() - 1;
    immutable z2 = 1 + pureMaker2();
}

/***********************************/

int[] pureMaker3() pure
{
    return new int[4];
}

void testDIP29_3()
{
    immutable x = pureMaker3()[];
}

/***********************************/

import core.vararg;

int* maker() pure { return null; }
int* maker1(int *) pure { return null; }
int* function(int *) pure makerfp1;
int* maker2(int *, ...) pure { return null; }
int* maker3(int) pure { return null; }
int* maker4(ref int) pure { return null; }
int* maker5(ref immutable int) pure { return null; }

void testDIP29_4()
{
    { immutable x = maker1(maker()); }
    { immutable x = maker1(null); }
    static assert(__traits(compiles, { immutable x = (*makerfp1)(maker()); }));
    { shared x = maker1(null); }
    { immutable x = maker2(null, 3); }
    { immutable int g; immutable x = maker2(null, 3, &g); }
    static assert(!__traits(compiles, { int g; immutable x = maker2(null, 3, &g); }));
    { immutable x = maker3(1); }
    static assert(!__traits(compiles, { int g; immutable x = maker4(g); }));
    { immutable int g; immutable x = maker5(g); }
}

/***********************************/

int[] test6(int[] a) pure @safe nothrow
{
    return a.dup;
}

/***********************************/

int*[] pureFoo() pure { return null; }


void testDIP29_5() pure
{
    { char[] s; immutable x = s.dup; }
    { immutable x = (cast(int*[])null).dup; }
    { immutable x = pureFoo(); }
    { immutable x = pureFoo().dup; }
}

/***********************************/

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    testDIP29_1();
    testDIP29_2();
    testDIP29_3();
    testDIP29_4();
    testDIP29_5();

    writefln("Success");
}
