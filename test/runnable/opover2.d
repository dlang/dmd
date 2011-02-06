
// Test operator overloading

import std.c.stdio;

/**************************************/

class A
{
    string opUnary(string s)()
    {
	printf("A.opUnary!(%.*s)\n", s.length, s.ptr);
	return s;
    }
}

void test1()
{
    auto a = new A();

    +a;
    -a;
    ~a;
    *a;
    ++a;
    --a;

    auto x = a++;
    assert(x == a);
    auto y = a--;
    assert(y == a);
}

/**************************************/

class A2
{
    T opCast(T)()
    {
        auto s = T.stringof;
	printf("A.opCast!(%.*s)\n", s.length, s.ptr);
	return T.init;
    }
}


void test2()
{
    auto a = new A2();

    auto x = cast(int)a;
    assert(x == 0);

    typedef int myint = 7;
    auto y = cast(myint)a;
    assert(y == 7);
}

/**************************************/

struct A3
{
    int opBinary(string s)(int i)
    {
	printf("A.opBinary!(%.*s)\n", s.length, s.ptr);
	return 0;
    }

    int opBinaryRight(string s)(int i) if (s == "/" || s == "*")
    {
	printf("A.opBinaryRight!(%.*s)\n", s.length, s.ptr);
	return 0;
    }

    T opCast(T)()
    {
        auto s = T.stringof;
	printf("A.opCast!(%.*s)\n", s.length, s.ptr);
	return T.init;
    }
}


void test3()
{
    A3 a;

    a + 3;
    4 * a;
    4 / a;
    a & 5;
}

/**************************************/

struct A4
{
    int opUnary(string s)()
    {
	printf("A.opUnary!(%.*s)\n", s.length, s.ptr);
	return 0;
    }

    T opCast(T)()
    {
        auto s = T.stringof;
	printf("A.opCast!(%.*s)\n", s.length, s.ptr);
	return T.init;
    }
}


void test4()
{
    A4 a;

    if (a)
	int x = 3;
    if (!a)
	int x = 3;
    if (!!a)
	int x = 3;
}

/**************************************/

class A5
{
    bool opEquals(Object o)
    {
	printf("A.opEquals!(%p)\n", o);
	return 1;
    }

    int opUnary(string s)()
    {
	printf("A.opUnary!(%.*s)\n", s.length, s.ptr);
	return 0;
    }

    T opCast(T)()
    {
        auto s = T.stringof;
	printf("A.opCast!(%.*s)\n", s.length, s.ptr);
	return T.init;
    }
}

class B5 : A5
{
    bool opEquals(Object o)
    {
	printf("B.opEquals!(%p)\n", o);
	return 1;
    }
}


void test5()
{
    A5 a = new A5();
    A5 a2 = new A5();
    B5 b = new B5();
    A n = null;

    if (a == a)
	int x = 3;
    if (a == a2)
	int x = 3;
    if (a == b)
	int x = 3;
    if (a == n)
	int x = 3;
    if (n == a)
	int x = 3;
    if (n == n)
	int x = 3;
}

/**************************************/

struct S6
{
    const bool opEquals(ref const S6 b)
    {
	printf("S.opEquals(S %p)\n", &b);
	return true;
    }

    const bool opEquals(ref const T6 b)
    {
	printf("S.opEquals(T %p)\n", &b);
	return true;
    }
}

struct T6
{
    const bool opEquals(ref const T6 b)
    {
	printf("T.opEquals(T %p)\n", &b);
	return true;
    }
/+
    const bool opEquals(ref const S6 b)
    {
	printf("T.opEquals(S %p)\n", &b);
	return true;
    }
+/
}


void test6()
{
    S6 s1;
    S6 s2;

    if (s1 == s2)
	int x = 3;

    T6 t;

    if (s1 == t)
	int x = 3;

    if (t == s2)
	int x = 3;
}

/**************************************/

struct S7
{
    const int opCmp(ref const S7 b)
    {
	printf("S.opCmp(S %p)\n", &b);
	return -1;
    }

    const int opCmp(ref const T7 b)
    {
	printf("S.opCmp(T %p)\n", &b);
	return -1;
    }
}

struct T7
{
    const int opCmp(ref const T7 b)
    {
	printf("T.opCmp(T %p)\n", &b);
	return -1;
    }
/+
    const int opCmp(ref const S7 b)
    {
	printf("T.opCmp(S %p)\n", &b);
	return -1;
    }
+/
}


void test7()
{
    S7 s1;
    S7 s2;

    if (s1 < s2)
	int x = 3;

    T7 t;

    if (s1 < t)
	int x = 3;

    if (t < s2)
	int x = 3;
}

/**************************************/

struct A8
{
    int opUnary(string s)()
    {
	printf("A.opUnary!(%.*s)\n", s.length, s.ptr);
	return 0;
    }

    int opIndexUnary(string s, T)(T i)
    {
	printf("A.opIndexUnary!(%.*s)(%d)\n", s.length, s.ptr, i);
	return 0;
    }

    int opIndexUnary(string s, T)(T i, T j)
    {
	printf("A.opIndexUnary!(%.*s)(%d, %d)\n", s.length, s.ptr, i, j);
	return 0;
    }

    int opSliceUnary(string s)()
    {
	printf("A.opSliceUnary!(%.*s)()\n", s.length, s.ptr);
	return 0;
    }

    int opSliceUnary(string s, T)(T i, T j)
    {
	printf("A.opSliceUnary!(%.*s)(%d, %d)\n", s.length, s.ptr, i, j);
	return 0;
    }
}


void test8()
{
    A8 a;

    -a;
    -a[3];
    -a[3, 4];
    -a[];
    -a[5 .. 6];
    --a[3];
}

/**************************************/

struct A9
{
    int opOpAssign(string s)(int i)
    {
	printf("A.opOpAssign!(%.*s)\n", s.length, s.ptr);
	return 0;
    }

    int opIndexOpAssign(string s, T)(int v, T i)
    {
	printf("A.opIndexOpAssign!(%.*s)(%d, %d)\n", s.length, s.ptr, v, i);
	return 0;
    }

    int opIndexOpAssign(string s, T)(int v, T i, T j)
    {
	printf("A.opIndexOpAssign!(%.*s)(%d, %d, %d)\n", s.length, s.ptr, v, i, j);
	return 0;
    }

    int opSliceOpAssign(string s)(int v)
    {
	printf("A.opSliceOpAssign!(%.*s)(%d)\n", s.length, s.ptr, v);
	return 0;
    }

    int opSliceOpAssign(string s, T)(int v, T i, T j)
    {
	printf("A.opSliceOpAssign!(%.*s)(%d, %d, %d)\n", s.length, s.ptr, v, i, j);
	return 0;
    }
}


void test9()
{
    A9 a;

    a += 8;
    a -= 8;
    a *= 8;
    a /= 8;
    a %= 8;
    a &= 8;
    a |= 8;
    a ^= 8;
    a <<= 8;
    a >>= 8;
    a >>>= 8;
    a ~= 8;
    a ^^= 8;

    a[3] += 8;
    a[3] -= 8;
    a[3] *= 8;
    a[3] /= 8;
    a[3] %= 8;
    a[3] &= 8;
    a[3] |= 8;
    a[3] ^= 8;
    a[3] <<= 8;
    a[3] >>= 8;
    a[3] >>>= 8;
    a[3] ~= 8;
    a[3] ^^= 8;

    a[3, 4] += 8;
    a[] += 8;
    a[5 .. 6] += 8;
}

/**************************************/

struct BigInt
{
    int opEquals(T)(T n) const
    {
        return 1;
    }

    int opEquals(T:int)(T n) const
    {
        return 1;
    }

    int opEquals(T:const(BigInt))(T n) const
    {
        return 1;
    }

}

int decimal(BigInt b, const BigInt c)
{
    while (b != c) {
    }
    return 1;
}

/**************************************/

struct Foo10
{
    int opUnary(string op)() { return 1; }
}

void test10()
{
    Foo10 foo;
    foo++;
}

/**************************************/

struct S4913
{
    bool opCast(T : bool)() { return true; }
}

int bug4913()
{
    if (S4913 s = S4913()) { return 83; }
    return 9;
}

static assert(bug4913() == 83);

/**************************************/

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

    printf("Success\n");
    return 0;
}

