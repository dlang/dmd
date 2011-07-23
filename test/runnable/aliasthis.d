
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
// 2779

void func2779a(int n, string s)
{
    assert(n == 10);
    assert(s == "str");
}

int func2779b1(int n, string s){ return 1; }

int func2779b2(int n, string s){ return 1; }
int func2779b2(Tup!(int, string) t){ return 2; }

int func2779b3(string s, int n){ return 1; }

void tfunc2779(A, B)(A a, B b)
{
    assert(a == 10);
    assert(b == "str");
}

void test2779()
{
    auto t1 = Tup!(int, string)(10, "str");
    func2779a(t1);   // t -> t.field

    auto t2 = Tup!(int, string)(10, "str");
    assert(func2779b1(t2) == 1);
    assert(func2779b2(t2) == 2);
    static assert(!__traits(compiles, func2779b3(t2)));

    auto t3 = tup(10, "str");
    tfunc2779(t3);

    alias Tup!(Tup!(int, double), Tup!(string, int[])) Tup41;
    alias Tup!(int, double, string, int[]) Tup42;
    auto t41 = Tup41(tup(10, 3.14), tup("str", [1,2]));
    auto t42 = Tup42(t41);
    assert(t42[0] == 10);
    assert(t42[1] == 3.14);
    assert(t42[2] == "str");
    assert(t42[3] == [1,2]);
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
    test2779();

    printf("Success\n");
    return 0;
}
