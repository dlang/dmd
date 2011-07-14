
extern (C) int printf(const(char*) fmt, ...);

struct Tup(T...)
{
    T field;
    alias field this;

    bool opEquals()(auto ref Tup rhs) const
    {
        foreach (i, _; T)
            if (field[i] != rhs.field[i])
                return false;
        return true;
    }
}

Tup!T tup(T...)(T fields)
{
    return typeof(return)(fields);
}

template Seq(T...)
{
    alias T Seq;
}

/**********************************************/

struct S
{
    int x;
    alias x this;
}

int foo(int i)
{
    return i * 2;
}

void test1()
{
    S s;
    s.x = 7;
    int i = -s;
    assert(i == -7);

    i = s + 8;
    assert(i == 15);

    i = s + s;
    assert(i == 14);

    i = 9 + s;
    assert(i == 16);

    i = foo(s);
    assert(i == 14);
}

/**********************************************/

class C
{
    int x;
    alias x this;
}

void test2()
{
    C s = new C();
    s.x = 7;
    int i = -s;
    assert(i == -7);

    i = s + 8;
    assert(i == 15);

    i = s + s;
    assert(i == 14);

    i = 9 + s;
    assert(i == 16);

    i = foo(s);
    assert(i == 14);
}

/**********************************************/

void test3()
{
    Tup!(int, double) t;
    t[0] = 1;
    t[1] = 1.1;
    assert(t[0] == 1);
    assert(t[1] == 1.1);
    printf("%d %g\n", t[0], t[1]);
}

/**********************************************/

struct Iter
{
    bool empty() { return true; }
    void popFront() { }
    ref Tup!(int, int) front() { return *new Tup!(int, int); }
    ref Iter opSlice() { return this; }
}

void test4()
{
    foreach (a; Iter()) { }
}

/**********************************************/

void test5()
{
    static struct Double1 {
        double val = 1;
        alias val this;
    }
    static Double1 x() { return Double1(); }
    x()++;
}

/**********************************************/
// 4773

void test4773()
{
    struct Rebindable
    {
        Object obj;
        @property const(Object) get(){ return obj; }
        alias get this;
    }

    Rebindable r;
    if (r) assert(0);
    r.obj = new Object;
    if (!r) assert(0);
}

/**********************************************/
// 5188

void test5188()
{
    struct S
    {
        int v = 10;
        alias v this;
    }

    S s;
    assert(s <= 20);
    assert(s != 14);
}

/***********************************************/

struct Foo {
  void opIndexAssign(int x, size_t i) {
    val = x;
  }
  void opSliceAssign(int x, size_t a, size_t b) {
    val = x;
  }
  int val;
}

struct Bar {
   Foo foo;
   alias foo this;
}

void test6() {
   Bar b;
   b[0] = 1;
   assert(b.val == 1);
   b[0 .. 1] = 2;
   assert(b.val == 2);
}

/**********************************************/
// 6366

void test6366()
{
    struct Zip
    {
        string str;
        size_t i;
        this(string s)
        {
            str = s;
        }
        @property const bool empty()
        {
            return i == str.length;
        }
        @property Tup!(size_t, char) front()
        {
            return typeof(return)(i, str[i]);
        }
        void popFront()
        {
            ++i;
        }
    }

    foreach (i, c; Zip("hello"))
    {
        switch (i)
        {
            case 0: assert(c == 'h');   break;
            case 1: assert(c == 'e');   break;
            case 2: assert(c == 'l');   break;
            case 3: assert(c == 'l');   break;
            case 4: assert(c == 'o');   break;
            default:assert(0);
        }
    }

    auto range(F...)(F field)
    {
        static struct Range {
            F field;
            bool empty = false;
            Tup!F front() { return typeof(return)(field); }
            void popFront(){ empty = true; }
        }
        return Range(field);
    }

    foreach (i, t; range(10, tup("str", [1,2]))){
        static assert(is(typeof(i) == int));
        static assert(is(typeof(t) == Tup!(string, int[])));
        assert(i == 10);
        assert(t == tup("str", [1,2]));
    }
    auto r1 = range(10, "str", [1,2]);
    auto r2 = range(tup(10, "str"), [1,2]);
    auto r3 = range(10, tup("str", [1,2]));
    auto r4 = range(tup(10, "str", [1,2]));
    alias Seq!(r1, r2, r3, r4) ranges;
    foreach (n, _; ranges)
    {
        foreach (i, s, a; ranges[n]){
            static assert(is(typeof(i) == int));
            static assert(is(typeof(s) == string));
            static assert(is(typeof(a) == int[]));
            assert(i == 10);
            assert(s == "str");
            assert(a == [1,2]);
        }
    }
}

/**********************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test4773();
    test5188();
    test6();
    test6366();

    printf("Success\n");
    return 0;
}
