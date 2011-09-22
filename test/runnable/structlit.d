import std.stdio;

struct S
{
    int x;
    int y;
}

/********************************************/

void test1()
{
    S s = S(1,2);
    assert(s.x == 1);
    assert(s.y == 2);
}

/********************************************/

void foo2(S s)
{
    assert(s.x == 1);
    assert(s.y == 2);
}

void test2()
{
    foo2( S(1,2) );
}

/********************************************/

S foo3()
{
    return S(1, 2);
}

void test3()
{
    S s = foo3();
    assert(s.x == 1);
    assert(s.y == 2);
}

/********************************************/

struct S4
{
    long x;
    long y;
    long z;
}

S4 foo4()
{
    return S4(1, 2, 3);
}

void test4()
{
    S4 s = foo4();
    assert(s.x == 1);
    assert(s.y == 2);
    assert(s.z == 3);
}

/********************************************/

struct S5
{
    long x;
    char y;
    long z;
}

S5 foo5()
{
    return S5(1, 2, 3);
}

void test5()
{
    S5 s = foo5();
    assert(s.x == 1);
    assert(s.y == 2);
    assert(s.z == 3);
}

/********************************************/

struct S6
{
    long x;
    char y;
    long z;
}

void test6()
{
    S6 s1 = S6(1,2,3);
    S6 s2 = S6(1,2,3);
    assert(s1 == s2);

    s1 = S6(4,5,6);
    s2 = S6(4,5,6);
    assert(s1 == s2);

    S6* p1 = &s1;
    S6* p2 = &s2;
    *p1 = S6(7,8,9);
    *p2 = S6(7,8,9);
    assert(*p1 == *p2);
}

/********************************************/

struct S7
{
    long x;
    char y;
    long z;
}

void test7()
{
    static S7 s1 = S7(1,2,3);
    static S7 s2 = S7(1,2,3);
    assert(s1 == s2);
}

/********************************************/

struct S8
{
    int i;
    string s;
}

void test8()
{
    S8 s = S8(3, "hello");
    assert(s.i == 3);
    assert(s.s == "hello");

    static S8 t = S8(4, "betty");
    assert(t.i == 4);
    assert(t.s == "betty");

    S8 u = S8(3, ['h','e','l','l','o']);
    assert(u.i == 3);
    assert(u.s == "hello");

    static S8 v = S8(4, ['b','e','t','t','y']);
    assert(v.i == 4);
    assert(v.s == "betty");
}

/********************************************/

struct S9
{
    int i;
    char[5] s;
}

void test9()
{
    S9 s = S9(3, "hello");
    assert(s.i == 3);
    assert(s.s == "hello");

    static S9 t = S9(4, "betty");
    assert(t.i == 4);
    assert(t.s == "betty");

    S9 u = S9(3, ['h','e','l','l','o']);
    assert(u.i == 3);
    assert(u.s == "hello");

    static S9 v = S9(4, ['b','e','t','t','y']);
    assert(v.i == 4);
    assert(v.s == "betty");
}

/********************************************/

alias int myint10;

struct S10
{
    int i;
    union
    {	int x = 2;
	int y;
    }
    int j = 3;
    myint10 k = 4;
}

void test10()
{
    S10 s = S10( 1 );
    assert(s.i == 1);
    assert(s.x == 2);
    assert(s.y == 2);
    assert(s.j == 3);
    assert(s.k == 4);

    static S10 t = S10( 1 );
    assert(t.i == 1);
    assert(t.x == 2);
    assert(t.y == 2);
    assert(t.j == 3);
    assert(t.k == 4);

    S10 u = S10( 1, 5 );
    assert(u.i == 1);
    assert(u.x == 5);
    assert(u.y == 5);
    assert(u.j == 3);
    assert(u.k == 4);

    static S10 v = S10( 1, 6 );
    assert(v.i == 1);
    assert(v.x == 6);
    assert(v.y == 6);
    assert(v.j == 3);
    assert(v.k == 4);
}

/********************************************/

struct S11
{
    int i;
    int j = 3;
}


void test11()
{
    static const s = S11( 1, 5 );
    static const i = s.i;
    assert(i == 1);
    static assert(s.j == 5);
}

/********************************************/

struct S12
{
        int[5] x;
        int[5] y = 3;
}

void test12()
{
        S12 s = S12();
	foreach (v; s.x)
	    assert(v == 0);
	foreach (v; s.y)
	    assert(v == 3);
}

/********************************************/

struct S13
{
        int[5] x;
        int[5] y;
	int[6][3] z;
}

void test13()
{
        S13 s = S13(0,3,4);
	foreach (v; s.x)
	    assert(v == 0);
	foreach (v; s.y)
	    assert(v == 3);
	for (int i = 0; i < 6; i++)
	{
	    for (int j = 0; j < 3; j++)
	    {
		assert(s.z[j][i] == 4);
	    }
	}
}

/********************************************/

struct Bug1914a
{
    const char[10] i = [1,0,0,0,0,0,0,0,0,0];
    char[10] x = i;
    int y=5;
}

struct Bug1914b
{
    const char[10] i = [0,0,0,0,0,0,0,0,0,0];
    char[10] x = i;
    int y=5;
}

struct Bug1914c
{
    const char[2] i = ['a', 'b'];
    const char[2][3] j = [['x', 'y'], ['p', 'q'], ['r', 's']];
    const char[2][3] k = ["cd", "ef", "gh"];
    const char[2][3] l = [['x', 'y'], ['p'], ['h', 'k']];
    char[2][3] x = i;
    int y = 5;
    char[2][3] z = j;
    char[2][3] w = k;
    int v=27;
    char[2][3] u = l;
    int t = 718;
}

struct T3198 {
   int g = 1;
}

class Foo3198 {
   int[5] x = 6;
   T3198[5] y = T3198(4);
}

void test3198and1914()
{
    Bug1914a a;
    assert(a.y==5, "bug 1914, non-zero init");
    Bug1914b b;
    assert(b.y==5, "bug 1914, zero init");
    Bug1914c c;
    assert(c.y==5, "bug 1914, multilevel init");
    assert(c.v==27, "bug 1914, multilevel init2");
    assert(c.x[2][1]=='b');
    assert(c.t==718, "bug 1914, multi3");
    assert(c.u[1][0]=='p');
    assert(c.u[1][1]==char.init);
    auto f = new Foo3198();
    assert(f.x[0]==6);
    assert(f.y[0].g==4, "bug 3198");
}

/********************************************/

struct T5885 {
    uint a, b;
}

double mulUintToDouble(T5885 t, double m) {
    return t.a * m;
}

void test5885()
{
    enum ae = mulUintToDouble(T5885(10, 0), 10.0);
    enum be = mulUintToDouble(T5885(10, 20), 10.0);
    static assert(ae == be);

    auto a = mulUintToDouble(T5885(10, 0), 10.0);
    auto b = mulUintToDouble(T5885(10, 20), 10.0);
    assert(a == b);
}

/********************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    test12();
    test13();
    test3198and1914();
    test5885();

    printf("Success\n");
    return 0;
}
