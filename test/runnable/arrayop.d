import std.math;

extern(C) int printf(const char*, ...);

string abc;

template Floating(T)
{
    T[3] a;
    T[3] b;
    T[3] c;

    T[] A()
    {
	printf("A\n");
	abc ~= "A";
	return a;
    }

    T[] B()
    {
	printf("B\n");
	abc ~= "B";
	return b;
    }

    T[] C()
    {
	printf("C\n");
	abc ~= "C";
	return c;
    }

    T D()
    {
	printf("D\n");
	abc ~= "D";
	return 4;
    }


    void testx()
    {
	a = [11, 22, 33];
	b = [1, 2, 3];
	c = [4, 5, 6];

	abc = null;
	A()[] = B()[] + C()[];
	assert(abc == "BCA");
	assert(a[0] == 5);
	assert(a[1] == 7);
	assert(a[2] == 9);

	abc = null;
	A()[] = B()[] + 4;
	assert(abc == "BA");
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 7);

	abc = null;
	A()[] = 4 + B()[];
	assert(abc == "BA");
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 7);

	abc = null;
	A()[] = D() + B()[];
	assert(abc == "DBA");
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 7);

	a = [11, 22, 33];
	abc = null;
	A()[] += B()[];
	assert(abc == "BA");
	assert(a[0] == 12);
	assert(a[1] == 24);
	assert(a[2] == 36);

	a = [11, 22, 33];
	A()[] += 4;
	assert(a[0] == 15);
	assert(a[1] == 26);
	assert(a[2] == 37);

	a = [11, 22, 33];
	A()[] -= 4;
	assert(a[0] == 7);
	assert(a[1] == 18);
	assert(a[2] == 29);

	a = [11, 22, 33];
	A()[] *= 4;
	assert(a[0] == 44);
	assert(a[1] == 88);
	assert(a[2] == 132);

	a = [4, 8, 32];
	A()[] /= 4;
	assert(a[0] == 1);
	assert(a[1] == 2);
	assert(a[2] == 8);

	a = [4, 8, 33];
	A()[] %= 4;
	assert(a[0] == 0);
	assert(a[1] == 0);
	assert(a[2] == 1);

	a = [11, 22, 33];
	abc = null;
	A()[] += 4 + B()[];
	assert(abc == "BA");
	assert(a[0] == 16);
	assert(a[1] == 28);
	assert(a[2] == 40);

	abc = null;
	A()[] = B()[] - C()[];
	assert(abc == "BCA");
	printf("%Lg, %Lg, %Lg\n", cast(real)a[0], cast(real)a[1], cast(real)a[2]);
	assert(a[0] == -3);
	assert(a[1] == -3);
	assert(a[2] == -3);

	abc = null;
	A()[] = -B()[] - C()[];
	assert(abc == "BCA");
	printf("%Lg, %Lg, %Lg\n", cast(real)a[0], cast(real)a[1], cast(real)a[2]);
	assert(a[0] == -5);
	assert(a[1] == -7);
	assert(a[2] == -9);

	abc = null;
	A()[] = B()[] + C()[] * 4;
	assert(abc == "BCA");
	printf("%Lg, %Lg, %Lg\n", cast(real)a[0], cast(real)a[1], cast(real)a[2]);
	assert(a[0] == 17);
	assert(a[1] == 22);
	assert(a[2] == 27);

	abc = null;
	A()[] = B()[] + C()[] * B()[];
	assert(abc == "BCBA");
	printf("%Lg, %Lg, %Lg\n", cast(real)a[0], cast(real)a[1], cast(real)a[2]);
	assert(a[0] == 5);
	assert(a[1] == 12);
	assert(a[2] == 21);

	abc = null;
	A()[] = B()[] + C()[] / 2;
	assert(abc == "BCA");
	printf("%Lg, %Lg, %Lg\n", cast(real)a[0], cast(real)a[1], cast(real)a[2]);
	assert(a[0] == 3);
	assert(a[1] == 4.5);
	assert(a[2] == 6);

	abc = null;
	A()[] = B()[] + C()[] % 2;
	assert(abc == "BCA");
	printf("%Lg, %Lg, %Lg\n", cast(real)a[0], cast(real)a[1], cast(real)a[2]);
	assert(a[0] == 1);
	assert(a[1] == 3);
	assert(a[2] == 3);
    }
}

mixin Floating!(float) Ffloat;
mixin Floating!(double) Fdouble;
mixin Floating!(real) Freal;

void test1()
{
    Ffloat.testx();
    Fdouble.testx();
    Freal.testx();
}

/************************************************************************/

template Integral(T)
{
    T[3] a;
    T[3] b;
    T[3] c;

    T[] A()
    {
	printf("A\n");
	abc ~= "A";
	return a;
    }

    T[] B()
    {
	printf("B\n");
	abc ~= "B";
	return b;
    }

    T[] C()
    {
	printf("C\n");
	abc ~= "C";
	return c;
    }

    T D()
    {
	printf("D\n");
	abc ~= "D";
	return 4;
    }


    void testx()
    {
	a = [11, 22, 33];
	b = [1, 2, 3];
	c = [4, 5, 6];

	abc = null;
	A()[] = B()[] + C()[];
	assert(abc == "BCA");
	assert(a[0] == 5);
	assert(a[1] == 7);
	assert(a[2] == 9);

	abc = null;
	A()[] = B()[] + 4;
	assert(abc == "BA");
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 7);

	abc = null;
	A()[] = 4 + B()[];
	assert(abc == "BA");
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 7);

	abc = null;
	A()[] = D() + B()[];
	assert(abc == "DBA");
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 7);

	a = [11, 22, 33];
	abc = null;
	A()[] += B()[];
	assert(abc == "BA");
	assert(a[0] == 12);
	assert(a[1] == 24);
	assert(a[2] == 36);

	a = [11, 22, 33];
	A()[] += 4;
	assert(a[0] == 15);
	assert(a[1] == 26);
	assert(a[2] == 37);

	a = [11, 22, 33];
	A()[] -= 4;
	assert(a[0] == 7);
	assert(a[1] == 18);
	assert(a[2] == 29);

	a = [11, 22, 27];
	A()[] *= 4;
	assert(a[0] == 44);
	assert(a[1] == 88);
	assert(a[2] == 108);

	a = [11, 22, 33];
	A()[] /= 4;
	assert(a[0] == 2);
	assert(a[1] == 5);
	assert(a[2] == 8);

	a = [11, 22, 33];
	A()[] %= 4;
	assert(a[0] == 3);
	assert(a[1] == 2);
	assert(a[2] == 1);

	a = [1, 2, 7];
	A()[] &= 4;
	assert(a[0] == 0);
	assert(a[1] == 0);
	assert(a[2] == 4);

	a = [1, 2, 7];
	A()[] |= 4;
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 7);

	a = [1, 2, 7];
	A()[] ^= 4;
	assert(a[0] == 5);
	assert(a[1] == 6);
	assert(a[2] == 3);

	a = [11, 22, 33];
	abc = null;
	A()[] += 4 + B()[];
	assert(abc == "BA");
	assert(a[0] == 16);
	assert(a[1] == 28);
	assert(a[2] == 40);

	abc = null;
	A()[] = B()[] - C()[];
	assert(abc == "BCA");
	printf("%lld, %lld, %lld\n", cast(long)a[0], cast(long)a[1], cast(long)a[2]);
	assert(a[0] == -3);
	assert(a[1] == -3);
	assert(a[2] == -3);

	abc = null;
	A()[] = -B()[] - C()[];
	assert(abc == "BCA");
	printf("%lld, %lld, %lld\n", cast(long)a[0], cast(long)a[1], cast(long)a[2]);
	assert(a[0] == -5);
	assert(a[1] == -7);
	assert(a[2] == -9);

	abc = null;
	A()[] = B()[] + C()[] * 4;
	assert(abc == "BCA");
	printf("%lld, %lld, %lld\n", cast(long)a[0], cast(long)a[1], cast(long)a[2]);
	assert(a[0] == 17);
	assert(a[1] == 22);
	assert(a[2] == 27);

	abc = null;
	A()[] = B()[] + C()[] * B()[];
	assert(abc == "BCBA");
	printf("%lld, %lld, %lld\n", cast(long)a[0], cast(long)a[1], cast(long)a[2]);
	assert(a[0] == 5);
	assert(a[1] == 12);
	assert(a[2] == 21);

	abc = null;
	A()[] = B()[] + C()[] / 2;
	assert(abc == "BCA");
	printf("%lld, %lld, %lld\n", cast(long)a[0], cast(long)a[1], cast(long)a[2]);
	assert(a[0] == 3);
	assert(a[1] == 4);
	assert(a[2] == 6);

	abc = null;
	A()[] = B()[] + C()[] % 2;
	assert(abc == "BCA");
	printf("%lld, %lld, %lld\n", cast(long)a[0], cast(long)a[1], cast(long)a[2]);
	assert(a[0] == 1);
	assert(a[1] == 3);
	assert(a[2] == 3);

	abc = null;
	A()[] = ~B()[];
	assert(abc == "BA");
	assert(a[0] == ~cast(T)1);
	assert(a[1] == ~cast(T)2);
	assert(a[2] == ~cast(T)3);

	abc = null;
	A()[] = B()[] & 2;
	assert(abc == "BA");
	assert(a[0] == 0);
	assert(a[1] == 2);
	assert(a[2] == 2);

	abc = null;
	A()[] = B()[] | 2;
	assert(abc == "BA");
	assert(a[0] == 3);
	assert(a[1] == 2);
	assert(a[2] == 3);

	abc = null;
	A()[] = B()[] ^ 2;
	assert(abc == "BA");
	assert(a[0] == 3);
	assert(a[1] == 0);
	assert(a[2] == 1);
    }
}

/************************************************************************/

mixin Integral!(byte) Fbyte;
mixin Integral!(short) Fshort;
mixin Integral!(int) Fint;
mixin Integral!(long) Flong;

void test2()
{
    Fbyte.testx();
    Fshort.testx();
    Fint.testx();
    Flong.testx();
}

/************************************************************************/

void test3()
{
    auto a = new double[10], b = a.dup, c = a.dup, d = a.dup;
    a[] = -(b[] * (c[] + 4)) + 5 * d[] / 3.0;
}

/************************************************************************/

void test4()
{
    int[] a, b;
    if (a && b) {}
}

/***************************************************/

void test4662()
{
    immutable double[] nums = [1.0, 2.0];

    static assert(!is(typeof({ nums[] += nums[]; })));
    static assert(!is(typeof({ nums[] -= nums[]; })));
    static assert(!is(typeof({ nums[] /= nums[]; })));
    static assert(!is(typeof({ nums[] += 4; })));
    static assert(!is(typeof({ nums[] /= 7; })));
}

/***************************************************/
// 5284

void bug5284_1()
{
    class C { int v; }

              C [] mda;
    immutable(C)[] ida;
    static assert(!__traits(compiles, (mda[] = ida[])));

              C [1] msa;
    immutable(C)[1] isa;
    static assert(!__traits(compiles, (msa[] = isa[])));

              C  m;
    immutable(C) i;
    static assert(!__traits(compiles, m = i));
}
void bug5284_2a()
{
    struct S { int v; }

              S [] mda;
    immutable(S)[] ida;
    mda[] = ida[];

              S [1] msa;
    immutable(S)[1] isa;
    msa[] = isa[];

              S  m = S();
    immutable(S) i = immutable(S)();
    m = i;
}
void bug5284_2b()
{
    struct S { int v; int[] arr; }

              S [] mda;
    immutable(S)[] ida;
    static assert(!__traits(compiles, (mda[] = ida[])));

              S [1] msa;
    immutable(S)[1] isa;
    static assert(!__traits(compiles, (msa[] = isa[])));

              S  m;
    immutable(S) i;
    static assert(!__traits(compiles, m = i));
}
void bug5284_3()
{
              int [] ma;
    immutable(int)[] ia;
    ma[] = ia[];

    int m;
    immutable(int) i;
    m = i;
}

void test5()
{
    bug5284_1();
    bug5284_2a();
    bug5284_2b();
    bug5284_3();
}

/************************************************************************/

void test6()
{
    int[10] a = [1,2,3,4,5,6,7,8,9,10];
    int[10] b;

    b = a[] ^^ 2;
    assert(b[0] == 1);
    assert(b[1] == 4);
    assert(b[2] == 9);
    assert(b[3] == 16);
    assert(b[4] == 25);
    assert(b[5] == 36);
    assert(b[6] == 49);
    assert(b[7] == 64);
    assert(b[8] == 81);
    assert(b[9] == 100);

    int[10] c = 3;
    b = a[] ^^ c[];
    assert(b[0] == 1);
    assert(b[1] == 8);
    assert(b[2] == 27);
    assert(b[3] == 64);
    assert(b[4] == 125);
    assert(b[5] == 216);
    assert(b[6] == 343);
    assert(b[7] == 512);
    assert(b[8] == 729);
    assert(b[9] == 1000);
}

/************************************************************************/

void test8390() {
    const int[] a = new int[5];
    int[] b = new int[5];
    b[] += a[];
}

/************************************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test8390();

    printf("Success\n");
    return 0;
}


version (none)
{
extern (C) T[] _arraySliceSliceAddSliceAssignd(T[] a, T[] c, T[] b)
{
    foreach (i; 0 .. a.length)
	a[i] = b[i] + c[i];
    return a;
}
}
