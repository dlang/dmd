import std.c.stdio;

template TypeTuple(T...){ alias T TypeTuple; }

/***************************************************/
// 2625

struct Pair {
    immutable uint g1;
    uint g2;
}

void test1() {
    Pair[1] stuff;
    static assert(!__traits(compiles, (stuff[0] = Pair(1, 2))));
}

/***************************************************/
// 5327

struct ID
{
    immutable int value;
}

struct Data
{
    ID id;
}
void test2()
{
    Data data = Data(ID(1));
    immutable int* val = &data.id.value;
    static assert(!__traits(compiles, data = Data(ID(2))));
}

/***************************************************/

struct S31A
{
    union
    {
        immutable int field1;
        immutable int field2;
    }

    enum result = false;
}
struct S31B
{
    union
    {
        immutable int field1;
        int field2;
    }

    enum result = true;
}
struct S31C
{
    union
    {
        int field1;
        immutable int field2;
    }

    enum result = true;
}
struct S31D
{
    union
    {
        int field1;
        int field2;
    }

    enum result = true;
}

struct S32A
{
    int dummy0;
    union
    {
        immutable int field1;
        int field2;
    }

    enum result = true;
}
struct S32B
{
    immutable int dummy0;
    union
    {
        immutable int field1;
        int field2;
    }

    enum result = false;
}


struct S32C
{
    union
    {
        immutable int field1;
        int field2;
    }
    int dummy1;

    enum result = true;
}
struct S32D
{
    union
    {
        immutable int field1;
        int field2;
    }
    immutable int dummy1;

    enum result = false;
}

void test3()
{
    foreach (S; TypeTuple!(S31A,S31B,S31C,S31D, S32A,S32B,S32C,S32D))
    {
        S s;
        static assert(__traits(compiles, s = s) == S.result);
    }
}

/***************************************************/
// 3511

struct S4
{
    private int _prop = 42;
    ref int property() { return _prop; }
}

void test4()
{
    S4 s;
    assert(s.property == 42);
    s.property = 23;    // Rewrite to s.property() = 23
    assert(s.property == 23);
}

/***************************************************/

struct S5
{
    int mX;
    string mY;

    ref int x()
    {
        return mX;
    }
    ref string y()
    {
        return mY;
    }

    ref int err(Object)
    {
        static int v;
        return v;
    }
}

void test5()
{
    S5 s;
    s.x += 4;
    assert(s.mX == 4);
    s.x -= 2;
    assert(s.mX == 2);
    s.x *= 4;
    assert(s.mX == 8);
    s.x /= 2;
    assert(s.mX == 4);
    s.x %= 3;
    assert(s.mX == 1);
    s.x <<= 3;
    assert(s.mX == 8);
    s.x >>= 1;
    assert(s.mX == 4);
    s.x >>>= 1;
    assert(s.mX == 2);
    s.x &= 0xF;
    assert(s.mX == 0x2);
    s.x |= 0x8;
    assert(s.mX == 0xA);
    s.x ^= 0xF;
    assert(s.mX == 0x5);

    s.x ^^= 2;
    assert(s.mX == 25);

    s.mY = "ABC";
    s.y ~= "def";
    assert(s.mY == "ABCdef");

    static assert(!__traits(compiles, s.err += 1));
}

/***************************************************/
// 6216

void test6216a()
{
    static class C{}

    static struct Xa{ int n; }
    static struct Xb{ int[] a; }
    static struct Xc{ C c; }
    static struct Xd{ void opAssign(typeof(this) rhs){} }
    static struct Xe{ void opAssign(T)(T rhs){} }
    static struct Xf{ void opAssign(int rhs){} }
    static struct Xg{ void opAssign(T)(T rhs)if(!is(T==typeof(this))){} }

    // has value type as member
    static struct S1 (X){ static if (!is(X==void)) X x; int n; }

    // has reference type as member
    static struct S2a(X){ static if (!is(X==void)) X x; int[] a; }
    static struct S2b(X){ static if (!is(X==void)) X x; C c; }

    // has identity opAssign
    static struct S3a(X){ static if (!is(X==void)) X x; void opAssign(typeof(this) rhs){} }
    static struct S3b(X){ static if (!is(X==void)) X x; void opAssign(T)(T rhs){} }

    // has non identity opAssign
    static struct S4a(X){ static if (!is(X==void)) X x; void opAssign(int rhs){} }
    static struct S4b(X){ static if (!is(X==void)) X x; void opAssign(T)(T rhs)if(!is(T==typeof(this))){} }

    enum result = [
        /*S1,   S2a,    S2b,    S3a,    S3b,    S4a,    S4b*/
/*- */  [true,  true,   true,   true,   true,   false,  false],
/*Xa*/  [true,  true,   true,   true,   true,   false,  false],
/*Xb*/  [true,  true,   true,   true,   true,   false,  false],
/*Xc*/  [true,  true,   true,   true,   true,   false,  false],
/*Xd*/  [true,  true,   true,   true,   true,   false,  false],
/*Xe*/  [true,  true,   true,   true,   true,   false,  false],
/*Xf*/  [false, false,  false,  true,   true,   false,  false],
/*Xg*/  [false, false,  false,  true,   true,   false,  false]
    ];

    pragma(msg, "\\\tS1\tS2a\tS2b\tS3a\tS3b\tS4a\tS4b");
    foreach (i, X; TypeTuple!(void,Xa,Xb,Xc,Xd,Xe,Xf,Xg))
    {
        S1!X  s1;
        S2a!X s2a;
        S2b!X s2b;
        S3a!X s3a;
        S3b!X s3b;
        S4a!X s4a;
        S4b!X s4b;

        pragma(msg,
                is(X==void) ? "-" : X.stringof,
                "\t", __traits(compiles, (s1  = s1)),
                "\t", __traits(compiles, (s2a = s2a)),
                "\t", __traits(compiles, (s2b = s2b)),
                "\t", __traits(compiles, (s3a = s3a)),
                "\t", __traits(compiles, (s3b = s3b)),
                "\t", __traits(compiles, (s4a = s4a)),
                "\t", __traits(compiles, (s4b = s4b))  );

        static assert(result[i] ==
            [   __traits(compiles, (s1  = s1)),
                __traits(compiles, (s2a = s2a)),
                __traits(compiles, (s2b = s2b)),
                __traits(compiles, (s3a = s3a)),
                __traits(compiles, (s3b = s3b)),
                __traits(compiles, (s4a = s4a)),
                __traits(compiles, (s4b = s4b))  ]);
    }
}

void test6216b()
{
    static int cnt = 0;

    static struct X
    {
        int n;
        void opAssign(X rhs){ cnt = 1; }
    }
    static struct S
    {
        int n;
        X x;
    }

    S s;
    s = s;
    assert(cnt == 1);
    // Built-in opAssign runs member's opAssign
}

void test6216c()
{
    static int cnt = 0;

    static struct X
    {
        int n;
        const void opAssign(const X rhs){ cnt = 2; }
    }
    static struct S
    {
        int n;
        const(X) x;
    }

    S s;
    const(S) cs;
    s = s;
    s = cs;     // cs is copied as mutable and assigned into s
    assert(cnt == 2);
//  cs = cs;    // built-in opAssin is only allowed with mutable object
}

/***************************************************/
// 6286

void test6286()
{
    const(int)[4] src = [1, 2, 3, 4];
    int[4] dst;
    dst = src;
    dst[] = src[];
    dst = 4;
    int[4][4] x;
    x = dst;
}

/***************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6216a();
    test6216b();
    test6216c();
    test6286();

    printf("Success\n");
    return 0;
}
