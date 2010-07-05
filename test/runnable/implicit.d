
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

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();

    writefln("Success");
}
