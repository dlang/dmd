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
// 4424

void test4424()
{
    static struct S
    {
        this(this) {}
        void opAssign(T)(T rhs) if (!is(T == S)) {}
    }
}

/***************************************************/
// 6174

struct TestCtor1_6174
{
    const int num;

    const int[2] sa1;
    const int[2][1] sa2;
    const int[][2] sa3;

    const int[] da1;
    const int[2][] da2;

    this(int _dummy)
    {
        static assert( __traits(compiles, { num         = 1;        }));    // OK

        auto pnum = &num;
        static assert(!__traits(compiles, { *pnum       = 1;        }));    // NG
        static assert( __traits(compiles, { *&num       = 1;        }));    // OK

        static assert( __traits(compiles, { sa1         = [1,2];    }));    // OK
        static assert( __traits(compiles, { sa1[0]      = 1;        }));    // OK
        static assert( __traits(compiles, { sa1[]       = 1;        }));    // OK
        static assert( __traits(compiles, { sa1[][]     = 1;        }));    // OK

        static assert( __traits(compiles, { sa2         = [[1,2]];  }));    // OK
        static assert( __traits(compiles, { sa2[0][0]   = 1;        }));    // OK
        static assert( __traits(compiles, { sa2[][0][]  = 1;        }));    // OK
        static assert( __traits(compiles, { sa2[0][][0] = 1;        }));    // OK

        static assert( __traits(compiles, { sa3         = [[1],[]]; }));    // OK
        static assert( __traits(compiles, { sa3[0]      = [1,2];    }));    // OK
        static assert(!__traits(compiles, { sa3[0][0]   = 1;        }));    // NG
        static assert( __traits(compiles, { sa3[]       = [1];      }));    // OK
        static assert( __traits(compiles, { sa3[][0]    = [1];      }));    // OK
        static assert(!__traits(compiles, { sa3[][0][0] = 1;        }));    // NG

        static assert( __traits(compiles, { da1         = [1,2];    }));    // OK
        static assert(!__traits(compiles, { da1[0]      = 1;        }));    // NG
        static assert(!__traits(compiles, { da1[]       = 1;        }));    // NG

        static assert( __traits(compiles, { da2         = [[1,2]];  }));    // OK
        static assert(!__traits(compiles, { da2[0][0]   = 1;        }));    // NG
        static assert(!__traits(compiles, { da2[]       = [1,2];    }));    // NG
        static assert(!__traits(compiles, { da2[][0]    = 1;        }));    // NG
        static assert(!__traits(compiles, { da2[0][]    = 1;        }));    // NG
    }
    void func()
    {
        static assert(!__traits(compiles, { num         = 1;        }));    // NG

        auto pnum = &num;
        static assert(!__traits(compiles, { *pnum       = 1;        }));    // NG
        static assert(!__traits(compiles, { *&num       = 1;        }));    // NG

        static assert(!__traits(compiles, { sa1         = [1,2];    }));    // NG
        static assert(!__traits(compiles, { sa1[0]      = 1;        }));    // NG
        static assert(!__traits(compiles, { sa1[]       = 1;        }));    // NG
        static assert(!__traits(compiles, { sa1[][]     = 1;        }));    // NG

        static assert(!__traits(compiles, { sa2         = [[1,2]];  }));    // NG
        static assert(!__traits(compiles, { sa2[0][0]   = 1;        }));    // NG
        static assert(!__traits(compiles, { sa2[][0][]  = 1;        }));    // NG
        static assert(!__traits(compiles, { sa2[0][][0] = 1;        }));    // NG

        static assert(!__traits(compiles, { sa3         = [[1],[]]; }));    // NG
        static assert(!__traits(compiles, { sa3[0]      = [1,2];    }));    // NG
        static assert(!__traits(compiles, { sa3[0][0]   = 1;        }));    // NG
        static assert(!__traits(compiles, { sa3[]       = [1];      }));    // NG
        static assert(!__traits(compiles, { sa3[][0]    = [1];      }));    // NG
        static assert(!__traits(compiles, { sa3[][0][0] = 1;        }));    // NG

        static assert(!__traits(compiles, { da1         = [1,2];    }));    // NG
        static assert(!__traits(compiles, { da1[0]      = 1;        }));    // NG
        static assert(!__traits(compiles, { da1[]       = 1;        }));    // NG

        static assert(!__traits(compiles, { da2         = [[1,2]];  }));    // NG
        static assert(!__traits(compiles, { da2[0][0]   = 1;        }));    // NG
        static assert(!__traits(compiles, { da2[]       = [1,2];    }));    // NG
        static assert(!__traits(compiles, { da2[][0]    = 1;        }));    // NG
        static assert(!__traits(compiles, { da2[0][]    = 1;        }));    // NG
    }
}

struct TestCtor2_6174
{
    static struct Data
    {
        const int x;
        int y;
    }
    const Data data;

    const Data[2] sa1;
    const Data[2][1] sa2;
    const Data[][2] sa3;

    const Data[] da1;
    const Data[2][] da2;

    this(int _dummy)
    {
        Data a;
        static assert( __traits(compiles, { data        = a;        }));    // OK
        static assert( __traits(compiles, { data.x      = 1;        }));    // OK
        static assert( __traits(compiles, { data.y      = 2;        }));    // OK

        auto pdata = &data;
        static assert(!__traits(compiles, { *pdata      = a;        }));    // NG
        static assert( __traits(compiles, { *&data      = a;        }));    // OK

        static assert( __traits(compiles, { sa1         = [a,a];    }));    // OK
        static assert( __traits(compiles, { sa1[0]      = a;        }));    // OK
        static assert( __traits(compiles, { sa1[]       = a;        }));    // OK
        static assert( __traits(compiles, { sa1[][]     = a;        }));    // OK

        static assert( __traits(compiles, { sa2         = [[a,a]];  }));    // OK
        static assert( __traits(compiles, { sa2[0][0]   = a;        }));    // OK
        static assert( __traits(compiles, { sa2[][0][]  = a;        }));    // OK
        static assert( __traits(compiles, { sa2[0][][0] = a;        }));    // OK

        static assert( __traits(compiles, { sa3         = [[a],[]]; }));    // OK
        static assert( __traits(compiles, { sa3[0]      = [a,a];    }));    // OK
        static assert(!__traits(compiles, { sa3[0][0]   = a;        }));    // NG
        static assert( __traits(compiles, { sa3[]       = [a];      }));    // OK
        static assert( __traits(compiles, { sa3[][0]    = [a];      }));    // OK
        static assert(!__traits(compiles, { sa3[][0][0] = a;        }));    // NG

        static assert( __traits(compiles, { da1         = [a,a];    }));    // OK
        static assert(!__traits(compiles, { da1[0]      = a;        }));    // NG
        static assert(!__traits(compiles, { da1[]       = a;        }));    // NG

        static assert( __traits(compiles, { da2         = [[a,a]];  }));    // OK
        static assert(!__traits(compiles, { da2[0][0]   = a;        }));    // NG
        static assert(!__traits(compiles, { da2[]       = [a,a];    }));    // NG
        static assert(!__traits(compiles, { da2[][0]    = a;        }));    // NG
        static assert(!__traits(compiles, { da2[0][]    = a;        }));    // NG
    }
    void func()
    {
        Data a;
        static assert(!__traits(compiles, { data        = a;        }));    // NG
        static assert(!__traits(compiles, { data.x      = 1;        }));    // NG
        static assert(!__traits(compiles, { data.y      = 2;        }));    // NG

        auto pdata = &data;
        static assert(!__traits(compiles, { *pdata      = a;        }));    // NG
        static assert(!__traits(compiles, { *&data      = a;        }));    // NG

        static assert(!__traits(compiles, { sa1         = [a,a];    }));    // NG
        static assert(!__traits(compiles, { sa1[0]      = a;        }));    // NG
        static assert(!__traits(compiles, { sa1[]       = a;        }));    // NG
        static assert(!__traits(compiles, { sa1[][]     = a;        }));    // NG

        static assert(!__traits(compiles, { sa2         = [[a,a]];  }));    // NG
        static assert(!__traits(compiles, { sa2[0][0]   = a;        }));    // NG
        static assert(!__traits(compiles, { sa2[][0][]  = a;        }));    // NG
        static assert(!__traits(compiles, { sa2[0][][0] = a;        }));    // NG

        static assert(!__traits(compiles, { sa3         = [[a],[]]; }));    // NG
        static assert(!__traits(compiles, { sa3[0]      = [a,a];    }));    // NG
        static assert(!__traits(compiles, { sa3[0][0]   = a;        }));    // NG
        static assert(!__traits(compiles, { sa3[]       = [a];      }));    // NG
        static assert(!__traits(compiles, { sa3[][0]    = [a];      }));    // NG
        static assert(!__traits(compiles, { sa3[][0][0] = a;        }));    // NG

        static assert(!__traits(compiles, { da1         = [a,a];    }));    // NG
        static assert(!__traits(compiles, { da1[0]      = a;        }));    // NG
        static assert(!__traits(compiles, { da1[]       = a;        }));    // NG

        static assert(!__traits(compiles, { da2         = [[a,a]];  }));    // NG
        static assert(!__traits(compiles, { da2[0][0]   = a;        }));    // NG
        static assert(!__traits(compiles, { da2[]       = [a,a];    }));    // NG
        static assert(!__traits(compiles, { da2[][0]    = a;        }));    // NG
        static assert(!__traits(compiles, { da2[0][]    = a;        }));    // NG
    }
}

const char gc6174;
const char[1] ga6174;
static this()
{
    gc6174 = 'a';    // OK
    ga6174[0] = 'a'; // line 5, Err
}
struct Foo6174
{
    const char cc;
    const char[1] array;
    this(char c)
    {
        cc = c;       // OK
        array = [c];  // line 12, Err
        array[0] = c; // line 12, Err
    }
}
void test6174a()
{
    auto foo = Foo6174('c');
}

/***************************************************/

void test6174Int()
{
    printf("## TestInt\n");

    static struct Test1
    {
        int x;
        this(int _)
        {
            x = 100;
        }
        void func()
        {
            x = 100;
        }
        void func() const
        {
            static assert(!__traits(compiles, x = 100));
        }
    }
    static struct Test2
    {
        const int x;
        this(int _)
        {
            x = 100;
        }
        void func()
        {
            static assert(!__traits(compiles, x = 100));
        }
        void func() const
        {
            static assert(!__traits(compiles, x = 100));
        }
    }
}

void test6174FA()   // field assignable
{
    printf("## TestFA\n");

    static struct D
    {
        int x;
        int y;
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174FN()   // field not assignable
{
    printf("## TestFN\n");

    static struct D
    {
        const int x;
        int y;
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            d.y = 100;
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174IAFA() // identity assignable & field assignable
{
    printf("## TestIAFA\n");

    static struct D
    {
        int x;
        int y;
        void opAssign(typeof(this) rhs){}
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            static assert(!__traits(compiles, d = D.init)); // operator overloading cannot bypass type check even if inside constructor
            d.x = 100;
            d.y = 100;
        }
        @disable void opAssign(typeof(this));   // disable built-in opAssign (this.d = p.d)
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174IAFN() // identity assignable & field not assignable
{
    printf("## TestIAFN\n");

    static struct D
    {
        const int x;
        int y;
        void opAssign(typeof(this) rhs){}
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            d.y = 100;
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            static assert(!__traits(compiles, d = D.init)); // operator overloading cannot bypass type check even if inside constructor
            d.x = 100;
            d.y = 100;
        }
        @disable void opAssign(typeof(this));   // disable built-in opAssign (this.d = p.d)
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174INFA() // identity assignable & field assignable
{
    printf("## TestINFA\n");

    static struct D
    {
        int x;
        int y;
        void opAssign(int dummy){}
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            static assert(!__traits(compiles, d = D.init));
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            d.x = 100;
            d.y = 100;
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            static assert(!__traits(compiles, d = D.init)); // operator overloading cannot bypass type check even if inside constructor
            d.x = 100;
            d.y = 100;
        }
        void opAssign(){}   // dummy for reject built-in opAssign (this.d = p.d)
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174INFN() // identity assignable & field not assignable
{
    printf("## TestINFN\n");

    static struct D
    {
        const int x;
        int y;
        void opAssign(int dummy){}
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            static assert(!__traits(compiles, d = D.init));
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            d.y = 100;
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            static assert(!__traits(compiles, d = D.init)); // operator overloading cannot bypass type check even if inside constructor
            d.x = 100;
            d.y = 100;
        }
        void opAssign(){}   // dummy for reject built-in opAssign (this.d = p.d)
        void func()
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            static assert(!__traits(compiles, d = D.init));
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174ICFA() // const identity assignable & field assignable
{
    printf("## TestICFA\n");

    static struct D
    {
        int x;
        int y;
        void opAssign(typeof(this) rhs) const {}
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func() const
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void opAssign(){}   // dummy for reject built-in opAssign (this.d = p.d)
        void func()
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174ICFN() // const identity assignable & field not assignable
{
    printf("## TestICFN\n");

    static struct D
    {
        const int x;
        int y;
        void opAssign(typeof(this) rhs) const {}
    }
    static struct Test1
    {
        D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void func()
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            d.y = 100;
        }
        void func() const
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
    static struct Test2
    {
        const D d;
        this(int _)
        {
            d = D.init;
            d.x = 100;
            d.y = 100;
        }
        void opAssign(){}   // dummy for reject built-in opAssign (this.d = p.d)
        void func()
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
        void func() const
        {
            d = D.init;
            static assert(!__traits(compiles, d.x = 100));
            static assert(!__traits(compiles, d.y = 100));
        }
    }
}

void test6174b()
{
    test6174Int();
    test6174FA();
    test6174FN();
    test6174IAFA();
    test6174IAFN();
    test6174INFA();
    test6174INFN();
    test6174ICFA();
    test6174ICFN();
}

void test6174c()
{
    static assert(!is(typeof({
        int func1a(int n)
        in{ n = 10; }
        body { return n; }
    })));
    static assert(!is(typeof({
        int func1b(int n)
        out(r){ r = 20; }
        body{ return n; }
    })));

    struct DataX
    {
        int x;
    }
    static assert(!is(typeof({
        DataX func2a(DataX n)
        in{ n.x = 10; }
        body { return n; }
    })));
    static assert(!is(typeof({
        DataX func2b(DataX n)
        in{}
        out(r){ r.x = 20; }
        body{ return n; }
    })));
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
/*Xd*/  [true,  true,   true,   true,   true,   true,   true ],
/*Xe*/  [true,  true,   true,   true,   true,   true,   true ],
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
// 6336

void test6336()
{
    // structs aren't identity assignable
    static struct S1
    {
        immutable int n;
    }
    static struct S2
    {
        void opAssign(int n){ assert(0); }
    }

    S1 s1;
    S2 s2;

    void f(S)(out S s){}
    static assert(!__traits(compiles, f(s1)));
    f(s2);
    // Out parameters refuse only S1 because it isn't blit assignable

    ref S g(S)(ref S s){ return s; }
    g(s1);
    g(s2);
    // Allow return by ref both S1 and S2
}

/***************************************************/
// 9077

struct S9077a
{
    void opAssign(int n) {}
    void test() { typeof(this) s; s = this; }
    this(this) {}
}
struct S9077b
{
    void opAssign()(int n) {}
    void test() { typeof(this) s; s = this; }
    this(this) {}
}

/***************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test4424();
    test6174a();
    test6174b();
    test6174c();
    test6216a();
    test6216b();
    test6216c();
    test6286();
    test6336();

    printf("Success\n");
    return 0;
}
