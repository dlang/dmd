// PERMUTE_ARGS: -inline -g -O

extern(C) int printf(const char*, ...);

/*******************************************/

class A
{
    int x = 7;

    int foo(int i)
    in
    {
        printf("A.foo.in %d\n", i);
        assert(i == 2);
        assert(x == 7);
        printf("A.foo.in pass\n");
    }
    out (result)
    {
        assert(result & 1);
        assert(x == 7);
    }
    body
    {
        return i;
    }
}

class B : A
{
    override int foo(int i)
    in
    {
        float f;
        printf("B.foo.in %d\n", i);
        assert(i == 4);
        assert(x == 7);
        f = f + i;
    }
    out (result)
    {
        assert(result < 8);
        assert(x == 7);
    }
    body
    {
        return i - 1;
    }
}

void test1()
{
    auto b = new B();
    b.foo(2);
    b.foo(4);
}

/*******************************************/

class A2
{
    int x = 7;

    int foo(int i)
    in
    {
        printf("A2.foo.in %d\n", i);
        assert(i == 2);
        assert(x == 7);
        printf("A2.foo.in pass\n");
    }
    out (result)
    {
        assert(result & 1);
        assert(x == 7);
    }
    body
    {
        return i;
    }
}

class B2 : A2
{
    override int foo(int i)
    in
    {
        float f;
        printf("B2.foo.in %d\n", i);
        assert(i == 4);
        assert(x == 7);
        f = f + i;
    }
    out (result)
    {
        assert(result < 8);
        assert(x == 7);
    }
    body
    {
        return i - 1;
    }
}

class C : B2
{
    override int foo(int i)
    in
    {
        float f;
        printf("C.foo.in %d\n", i);
        assert(i == 6);
        assert(x == 7);
        f = f + i;
    }
    out (result)
    {
        assert(result == 1 || result == 3 || result == 5);
        assert(x == 7);
    }
    body
    {
        return i - 1;
    }
}

void test2()
{
    auto c = new C();
    c.foo(2);
    c.foo(4);
    c.foo(6);
}

/*******************************************/

void fun(int x)
in {
    if (x < 0) throw new Exception("a");
}
body {
}

void test3()
{
    fun(1);
}

/*******************************************/

interface Stack {
    int pop()
//   in { printf("pop.in\n"); }
    out(result) {
        printf("pop.out\n");
        assert(result == 3);
    }
}

class CC : Stack
{
    int pop()
    //out (result) { printf("CC.pop.out\n"); } body
    {
        printf("CC.pop.in\n");
        return 3;
    }
}

void test4()
{
    auto cc = new CC();
    cc.pop();
}

/*******************************************/

int mul100(int n)
out(result)
{
    assert(result == 500);
}
body
{
    return n * 100;
}

void test5()
{
    mul100(5);
}

/*******************************************/
// 3273

// original case
struct Bug3273
{
    ~this() {}
    invariant() {}
}

// simplest case
ref int func3273()
out(r)
{
    // Regression check of issue 3390
    static assert(!__traits(compiles, r = 1));
}
body
{
    static int dummy;
    return dummy;
}

void test6()
{
    func3273() = 1;
    assert(func3273() == 1);
}

/*******************************************/

/+
// http://d.puremagic.com/issues/show_bug.cgi?id=3722

class Bug3722A
{
    void fun() {}
}
class Bug3722B : Bug3722A
{
    override void fun() in { assert(false); } body {}
}

void test6()
{
    auto x = new Bug3722B();
    x.fun();
}
+/

/*******************************************/

auto test7foo()
in{
    ++cnt;
}body{
    ++cnt;
    return "str";
}

void test7()
{
    cnt = 0;
    assert(test7foo() == "str");
    assert(cnt == 2);
}

/*******************************************/

auto foo8()
out(r){
    ++cnt;
    assert(r == 10);
}body{
    ++cnt;
    return 10;
}

auto bar8()
out{
    ++cnt;
}body{
    ++cnt;
}

void test8()
{
    cnt = 0;
    assert(foo8() == 10);
    assert(cnt == 2);

    cnt = 0;
    bar8();
    assert(cnt == 2);
}

/*******************************************/
// from fail317

void test9()
{
    auto f1 = function() body { }; // fine
    auto f2 = function() in { } body { }; // fine
    auto f3 = function() out { } body { }; // error
    auto f4 = function() in { } out { } body { }; // error

    auto d1 = delegate() body { }; // fine
    auto d2 = delegate() in { } body { }; // fine
    auto d3 = delegate() out { } body { }; // error
    auto d4 = delegate() in { } out { } body { }; // error
}

/*******************************************/
// 4785

int cnt;

auto foo4785()
in{
    int r;
    ++cnt;
}
out(r){
    assert(r == 10);
    ++cnt;
}body{
    ++cnt;
    int r = 10;
    return r;
}
void test4785()
{
    cnt = 0;
    assert(foo4785() == 10);
    assert(cnt == 3);
}

/*******************************************/
// 5039

class C5039 {
    int x;

    invariant() {
        assert( x < int.max );
    }

    auto foo() {
        return x;
    }
}

/*******************************************/
// 5204

interface IFoo5204
{
    IFoo5204 bar()
    out {}
}
class Foo5204 : IFoo5204
{
    Foo5204 bar() { return null; }
}

/*******************************************/
// 6417

class Bug6417
{
    void bar()
    in
    {
        int i = 14;
        assert(i == 14);
        auto dg = (){
            //printf("in: i = %d\n", i);
            assert(i == 14, "in contract failure");
        };
        dg();
    }
    out
    {
        int j = 10;
        assert(j == 10);
        auto dg = (){
            //printf("out: j = %d\n", j);
            assert(j == 10, "out contract failure");
        };
        dg();
    }
    body {}
}

void test6417()
{
    (new Bug6417).bar();
}

/*******************************************/
// 7218

void test7218()
{
    size_t foo()  in{}  out{}  body{ return 0; } // OK
    size_t bar()  in{}/*out{}*/body{ return 0; } // OK
    size_t hoo()/*in{}*/out{}  body{ return 0; } // NG1
    size_t baz()/*in{}  out{}*/body{ return 0; } // NG2
}

/*******************************************/
// 7699

class P7699
{
    void f(int n) in {
        assert (n);
    } body { }
}
class D7699 : P7699
{
    override void f(int n) in { } body { }
}

/*******************************************/
// 7883

// Segmentation fault
class AA7883
{
    int foo()
    out (r1) { }
    body { return 1; }
}

class BA7883 : AA7883
{
    override int foo()
    out (r2) { }
    body { return 1; }
}

class CA7883 : BA7883
{
    override int foo()
    body { return 1; }
}

// Error: undefined identifier r2, did you mean variable r3?
class AB7883
{
    int foo()
    out (r1) { }
    body { return 1; }
}

class BB7883 : AB7883
{
    override int foo()
    out (r2) { }
    body { return 1; }

}

class CB7883 : BB7883
{
    override int foo()
    out (r3) { }
    body { return 1; }
}

// Error: undefined identifier r3, did you mean variable r4?
class AC7883
{
    int foo()
    out (r1) { }
    body { return 1; }
}

class BC7883 : AC7883
{
    override int foo()
    out (r2) { }
    body { return 1; }
}

class CC7883 : BC7883
{
    override int foo()
    out (r3) { }
    body { return 1; }
}

class DC7883 : CC7883
{
    override int foo()
    out (r4) { }
    body { return 1; }
}

/*******************************************/
// 7892

struct S7892
{
    @disable this();
    this(int x) {}
}

S7892 f7892()
out (result) {}     // case 1
body
{
    return S7892(1);
}

interface I7892
{
    S7892 f();
}
class C7892
{
    invariant() {}  // case 2

    S7892 f()
    {
        return S7892(1);
    }
}

/*******************************************/
// 8066

struct CLCommandQueue
{
    invariant() {}

//private:
    int enqueueNativeKernel()
    {
        assert(0, "implement me");
    }
}

/*******************************************/
// 8073

struct Container8073
{
    int opApply (int delegate(ref int) dg) { return 0; }
}

class Bug8073
{
    static int test;
    int foo()
    out(r) { test = 7; } body
    {
        Container8073 ww;
        foreach( xxx ; ww ) {  }
        return 7;
    }

    ref int bar()
    out { } body
    {
        Container8073 ww;
        foreach( xxx ; ww ) {  }
        test = 7;
        return test;
    }
}
void test8073()
{
    auto c = new Bug8073();
    assert(c.foo() == 7);
    assert(c.test == 7);

    auto p = &c.bar();
    assert(p == &c.test);
    assert(*p == 7);
}

/*******************************************/
// 8093

void test8093()
{
    static int g = 10;
    static int* p;

    enum fbody = q{
        static struct S {
            int opApply(scope int delegate(ref int) dg) { return dg(g); }
        }
        S s;
        foreach (ref e; s)
            return g;
        assert(0);
    };

    ref int foo_ref1() out(r) { assert(&r is &g && r == 10); }
    body { mixin(fbody); }

    ref int foo_ref2()
    body { mixin(fbody); }

    { auto q = &foo_ref1(); assert(q is &g && *q == 10); }
    { auto q = &foo_ref2(); assert(q is &g && *q == 10); }

    int foo_val1() out(r) { assert(&r !is &g && r == 10); }
    body { mixin(fbody); }

    int foo_val2()
    body { mixin(fbody); }

    { auto n = foo_val1(); assert(&n !is &g && n == 10); }
    { auto n = foo_val2(); assert(&n !is &g && n == 10); }
}

/*******************************************/
// 9383

class A9383
{
    static void delegate() dg;
    static int val;

    void failInBase() { assert(typeid(this) is typeid(A9383)); }

    // in-contract tests
    void foo1(int i) in  { A9383.val = i; failInBase; } body { }                        // no closure
    void foo2(int i) in  { A9383.val = i; failInBase; } body { int x; dg = { ++x; }; }  // closure [local]
    void foo3(int i) in  { A9383.val = i; failInBase; } body {        dg = { ++i; }; }  // closure [parameter]
    void foo4(int i) in  { A9383.val = i; failInBase; } body { }                        // no closure
    void foo5(int i) in  { A9383.val = i; failInBase; } body { }                        // no closure
    void foo6(int i) in  { A9383.val = i; failInBase; } body { int x; dg = { ++x; }; }  // closure [local]
    void foo7(int i) in  { A9383.val = i; failInBase; } body {        dg = { ++i; }; }  // closure [parameter]

    // out-contract tests
    void bar1(int i) out { A9383.val = i;             } body { }                        // no closure
    void bar2(int i) out { A9383.val = i;             } body { int x; dg = { ++x; }; }  // closure [local]
    void bar3(int i) out { A9383.val = i;             } body {        dg = { ++i; }; }  // closure [parameter]
    void bar4(int i) out { A9383.val = i;             } body { }                        // no closure
    void bar5(int i) out { A9383.val = i;             } body { }                        // no closure
    void bar6(int i) out { A9383.val = i;             } body { int x; dg = { ++x; }; }  // closure [local]
    void bar7(int i) out { A9383.val = i;             } body {        dg = { ++i; }; }  // closure [parameter]
}

class B9383 : A9383
{
    static int val;

    // in-contract tests
    override void foo1(int i) in  { B9383.val = i; } body { }                           // -> no closure
    override void foo2(int i) in  { B9383.val = i; } body { int x; dg = { ++x; }; }     // -> closure [local] appears
    override void foo3(int i) in  { B9383.val = i; } body {        dg = { ++i; }; }     // -> closure [parameter]
    override void foo4(int i) in  { B9383.val = i; } body { int x; dg = { ++x; }; }     // -> closure [local] appears
    override void foo5(int i) in  { B9383.val = i; } body {        dg = { ++i; }; }     // -> closure [parameter] appears
    override void foo6(int i) in  { B9383.val = i; } body { }                           // -> closure [local] disappears
    override void foo7(int i) in  { B9383.val = i; } body { }                           // -> closure [parameter] disappears

    // out-contract tests
    override void bar1(int i) out { B9383.val = i; } body { }                           // -> no closure
    override void bar2(int i) out { B9383.val = i; } body { int x; dg = { ++x; }; }     // -> closure [local] appears
    override void bar3(int i) out { B9383.val = i; } body {        dg = { ++i; }; }     // -> closure [parameter]
    override void bar4(int i) out { B9383.val = i; } body { int x; dg = { ++x; }; }     // -> closure [local] appears
    override void bar5(int i) out { B9383.val = i; } body {        dg = { ++i; }; }     // -> closure [parameter] appears
    override void bar6(int i) out { B9383.val = i; } body { }                           // -> closure [local] disappears
    override void bar7(int i) out { B9383.val = i; } body { }                           // -> closure [parameter] disappears
}

void test9383()
{
    auto a = new A9383();
    auto b = new B9383();

    // base class in-contract is used from derived class.       // base                   derived
    b.foo1(101); assert(A9383.val == 101 && B9383.val == 101);  // no closure          -> no closure
    b.foo2(102); assert(A9383.val == 102 && B9383.val == 102);  // closure [local]     -> closure [local] appears
    b.foo3(103); assert(A9383.val == 103 && B9383.val == 103);  // closure [parameter] -> closure [parameter]
    b.foo4(104); assert(A9383.val == 104 && B9383.val == 104);  // no closure          -> closure [local] appears
    b.foo5(105); assert(A9383.val == 105 && B9383.val == 105);  // no closure          -> closure [parameter] appears
    b.foo6(106); assert(A9383.val == 106 && B9383.val == 106);  // closure [local]     -> closure [local] disappears
    b.foo7(107); assert(A9383.val == 107 && B9383.val == 107);  // closure [parameter] -> closure [parameter] disappears

    // base class out-contract is used from derived class.      // base                   derived
    b.bar1(101); assert(A9383.val == 101 && B9383.val == 101);  // no closure          -> no closure
    b.bar2(102); assert(A9383.val == 102 && B9383.val == 102);  // closure [local]     -> closure [local] appears
    b.bar3(103); assert(A9383.val == 103 && B9383.val == 103);  // closure [parameter] -> closure [parameter]
    b.bar4(104); assert(A9383.val == 104 && B9383.val == 104);  // no closure          -> closure [local] appears
    b.bar5(105); assert(A9383.val == 105 && B9383.val == 105);  // no closure          -> closure [parameter] appears
    b.bar6(106); assert(A9383.val == 106 && B9383.val == 106);  // closure [local]     -> closure [local] disappears
    b.bar7(107); assert(A9383.val == 107 && B9383.val == 107);  // closure [parameter] -> closure [parameter] disappears

    // in-contract in base class.
    a.foo1(101); assert(A9383.val == 101);      // no closure
    a.foo2(102); assert(A9383.val == 102);      // closure [local]
    a.foo3(103); assert(A9383.val == 103);      // closure [parameter]

    // out-contract in base class.
    a.bar1(101); assert(A9383.val == 101);      // no closure
    a.bar2(102); assert(A9383.val == 102);      // closure [local]
    a.bar3(103); assert(A9383.val == 103);      // closure [parameter]
}

/*******************************************/
// 10479

class B10479
{
    B10479 foo()
    out { } body { return null; }
}

class D10479 : B10479
{
    override D10479 foo() { return null; }
}

/*******************************************/
// 10596

class Foo10596
{
    auto bar()
    out (result) { }
    body { return 0; }
}

/*******************************************/
// 10721

class Foo10721
{
    this()
    out { }
    body { }

    ~this()
    out { }
    body { }
}

struct Bar10721
{
    this(this)
    out { }
    body { }
}

/*******************************************/
// 10981

class C10981
{
    void foo(int i) pure
    in { assert(i); }
    out { assert(i); }
    body {}
}

/*******************************************/
// 14779

class C14779
{
    final void foo(int v)
    in  { assert(v == 0); }
    out { assert(v == 0); }
    body
    {
    }
}

void test14779()
{
    auto c = new C14779();
    c.foo(0);
}

/*******************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
//    test6();
    test7();
    test8();
    test9();
    test4785();
    test6417();
    test7218();
    test8073();
    test8093();
    test9383();
    test14779();

    printf("Success\n");
    return 0;
}
