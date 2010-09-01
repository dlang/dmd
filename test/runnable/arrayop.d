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

/************************************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();

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
