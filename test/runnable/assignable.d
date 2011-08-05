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
    test6286();

    printf("Success\n");
    return 0;
}
