import core.vararg;

extern (C) int printf(const char*, ...);

/***************************************************/
// lambda syntax check

auto una(alias dg)(int n)
{
    return dg(n);
}
auto bin(alias dg)(int n, int m)
{
    return dg(n, m);
}
void test1()
{
    assert(una!(      a  => a*2 )(2) == 4);
    assert(una!( (    a) => a*2 )(2) == 4);
    assert(una!( (int a) => a*2 )(2) == 4);
    assert(una!(             (    a){ return a*2; } )(2) == 4);
    assert(una!( function    (    a){ return a*2; } )(2) == 4);
    assert(una!( function int(    a){ return a*2; } )(2) == 4);
    assert(una!( function    (int a){ return a*2; } )(2) == 4);
    assert(una!( function int(int a){ return a*2; } )(2) == 4);
    assert(una!( delegate    (    a){ return a*2; } )(2) == 4);
    assert(una!( delegate int(    a){ return a*2; } )(2) == 4);
    assert(una!( delegate    (int a){ return a*2; } )(2) == 4);
    assert(una!( delegate int(int a){ return a*2; } )(2) == 4);

    // partial parameter specialization syntax
    assert(bin!( (    a,     b) => a*2+b )(2,1) == 5);
    assert(bin!( (int a,     b) => a*2+b )(2,1) == 5);
    assert(bin!( (    a, int b) => a*2+b )(2,1) == 5);
    assert(bin!( (int a, int b) => a*2+b )(2,1) == 5);
    assert(bin!(             (    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!(             (int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!(             (    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!(             (int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(int a, int b){ return a*2+b; } )(2,1) == 5);
}

/***************************************************/
// on initializer

void test2()
{
    // explicit typed binding ignite parameter types inference
    int function(int) fn1 = a => a*2;                               assert(fn1(2) == 4);
    int function(int) fn2 =             (    a){ return a*2; };     assert(fn2(2) == 4);
    int function(int) fn3 = function    (    a){ return a*2; };     assert(fn3(2) == 4);
    int function(int) fn4 = function int(    a){ return a*2; };     assert(fn4(2) == 4);
    int function(int) fn5 = function    (int a){ return a*2; };     assert(fn5(2) == 4);
    int function(int) fn6 = function int(int a){ return a*2; };     assert(fn6(2) == 4);
    int delegate(int) dg1 = a => a*2;                               assert(dg1(2) == 4);
    int delegate(int) dg2 =             (    a){ return a*2; };     assert(dg2(2) == 4);
    int delegate(int) dg3 = delegate    (    a){ return a*2; };     assert(dg3(2) == 4);
    int delegate(int) dg4 = delegate int(    a){ return a*2; };     assert(dg4(2) == 4);
    int delegate(int) dg5 = delegate    (int a){ return a*2; };     assert(dg5(2) == 4);
    int delegate(int) dg6 = delegate int(int a){ return a*2; };     assert(dg6(2) == 4);

    // funciton/delegate mismatching always raises an error
    static assert(!__traits(compiles, { int function(int) xfg3 = delegate    (    a){ return a*2; }; }));
    static assert(!__traits(compiles, { int function(int) xfg4 = delegate int(    a){ return a*2; }; }));
    static assert(!__traits(compiles, { int function(int) xfg5 = delegate    (int a){ return a*2; }; }));
    static assert(!__traits(compiles, { int function(int) xfg6 = delegate int(int a){ return a*2; }; }));
    static assert(!__traits(compiles, { int delegate(int) xdn3 = function    (    a){ return a*2; }; }));
    static assert(!__traits(compiles, { int delegate(int) xdn4 = function int(    a){ return a*2; }; }));
    static assert(!__traits(compiles, { int delegate(int) xdn5 = function    (int a){ return a*2; }; }));
    static assert(!__traits(compiles, { int delegate(int) xdn6 = function int(int a){ return a*2; }; }));

    // auto binding requires explicit parameter types at least
    static assert(!__traits(compiles, { auto afn1 = a => a*2;                           }));
    static assert(!__traits(compiles, { auto afn2 =             (    a){ return a*2; }; }));
    static assert(!__traits(compiles, { auto afn3 = function    (    a){ return a*2; }; }));
    static assert(!__traits(compiles, { auto afn4 = function int(    a){ return a*2; }; }));
    static assert(!__traits(compiles, { auto adg3 = delegate    (    a){ return a*2; }; }));
    static assert(!__traits(compiles, { auto adg4 = delegate int(    a){ return a*2; }; }));
    auto afn5 = function    (int a){ return a*2; };     assert(afn5(2) == 4);
    auto afn6 = function int(int a){ return a*2; };     assert(afn6(2) == 4);
    auto adg5 = delegate    (int a){ return a*2; };     assert(adg5(2) == 4);
    auto adg6 = delegate int(int a){ return a*2; };     assert(adg6(2) == 4);

    // partial specialized lambda
    string delegate(int, string) dg =
        (n, string s){
            string r = "";
            foreach (_; 0..n) r~=s;
            return r;
        };
    assert(dg(2, "str") == "strstr");
}

/***************************************************/
// on return statement

void test3()
{
    // inference matching system is same as on initializer
    int delegate(int) mul(int x)
    {
        return a => a * x;
    }
    assert(mul(5)(2) == 10);
}

/***************************************************/
// on function arguments

auto foo4(int delegate(int) dg) { return dg(10); }
auto foo4(int delegate(int, int) dg) { return dg(10, 20); }

void nbar4fp(void function(int) fp) { }
void nbar4dg(void delegate(int) dg) { }
void tbar4fp(T,R)(R function(T) dg) { static assert(is(typeof(dg) == void function(int))); }
void tbar4dg(T,R)(R delegate(T) dg) { static assert(is(typeof(dg) == void delegate(int))); }

auto nbaz4(void function() fp) { return 1; }
auto nbaz4(void delegate() dg) { return 2; }
auto tbaz4(R)(R function() dg) { static assert(is(R == void)); return 1; }
auto tbaz4(R)(R delegate() dg) { static assert(is(R == void)); return 2; }

auto thoo4(T)(T lambda){ return lambda; }

void tfun4a()(int function(int) a){}
void tfun4b(T)(T function(T) a){}
void tfun4c(T)(T f){}

void test4()
{
    int v;

    // parameter type inference + overload resolution
    assert(foo4((a)   => a * 2) == 20);
    assert(foo4((a,b) => a * 2 + b) == 40);

    // function/delegate inference
    nbar4fp((int x){ });
    nbar4dg((int x){ });
    tbar4fp((int x){ });
    tbar4dg((int x){ });

    // function/delegate inference + overload resolution
    assert(nbaz4({ }) == 1);
    assert(nbaz4({ v = 1; }) == 2);
    assert(tbaz4({ }) == 1);
    assert(tbaz4({ v = 1; }) == 2);

    // template function deduction
    static assert(is(typeof(thoo4({ })) : void function()));
    static assert(is(typeof(thoo4({ v = 1;  })) : void delegate()));

    tfun4a(a => a);
    static assert(!__traits(compiles, { tfun4b(a => a); }));
    static assert(!__traits(compiles, { tfun4c(a => a); }));
}

void fsvarg4(int function(int)[] a...){}
void fcvarg4(int dummy, ...){}

void tsvarg4a()(int function(int)[] a...){}
void tsvarg4b(T)(T function(T)[] a...){}
void tsvarg4c(T)(T [] a...){}
void tcvarg4()(int dummy, ...){}

void test4v()
{
    fsvarg4(function(int a){ return a; });      // OK
    fsvarg4(a => a);                            // OK

    fcvarg4(0, function(int a){ return a; });   // OK
    static assert(!__traits(compiles, { fcvarg4(0, a => a); }));

    tsvarg4a(function(int a){ return a; });     // OK
    tsvarg4b(function(int a){ return a; });     // OK
    tsvarg4c(function(int a){ return a; });     // OK
    tsvarg4a(a => a);
    static assert(!__traits(compiles, { tsvarg4b(a => a); }));
    static assert(!__traits(compiles, { tsvarg4c(a => a); }));

    tcvarg4(0, function(int a){ return a; });   // OK
    static assert(!__traits(compiles, { tcvarg4(0, a => a); }));
}

/***************************************************/
// on CallExp::e1

void test5()
{
    assert((a => a*2)(10) == 20);
    assert((    a,        s){ return s~s; }(10, "str") == "strstr");
    assert((int a,        s){ return s~s; }(10, "str") == "strstr");
    assert((    a, string s){ return s~s; }(10, "str") == "strstr");
    assert((int a, string s){ return s~s; }(10, "str") == "strstr");
}

/***************************************************/
// escape check to nested function symbols

void checkNestedRef(alias dg)(bool isnested)
{
    static if (is(typeof(dg) == delegate))
        enum isNested = true;
    else static if ((is(typeof(dg) PF == F*, F) && is(F == function)))
        enum isNested = false;
    else
        static assert(0);

    assert(isnested == isNested);
    dg();
}

void freeFunc(){}

void test6()
{
    static void localFunc(){}
    void nestedLocalFunc(){}

    checkNestedRef!({  })(false);

    checkNestedRef!({ freeFunc(); })(false);
    checkNestedRef!({ localFunc(); })(false);
    checkNestedRef!({ nestedLocalFunc(); })(true);
    checkNestedRef!({ void inner(){} inner(); })(false);

    checkNestedRef!({ auto f = &freeFunc; })(false);
    checkNestedRef!({ auto f = &localFunc; })(false);
    checkNestedRef!({ auto f = &nestedLocalFunc; })(true);
    checkNestedRef!({ void inner(){} auto f = &inner; })(false);
}

/***************************************************/
// on AssignExp::e2

void test7()
{
    int function(int) fp;
    fp = a => a;
    fp = (int a) => a;
    fp = function(int a) => a;
    fp = function int(int a) => a;
    static assert(!__traits(compiles, { fp = delegate(int a) => a; }));
    static assert(!__traits(compiles, { fp = delegate int(int a) => a; }));

    int delegate(int) dg;
    dg = a => a;
    dg = (int a) => a;
    dg = delegate(int a) => a;
    dg = delegate int(int a) => a;
    static assert(!__traits(compiles, { dg = function(int a) => a; }));
    static assert(!__traits(compiles, { dg = function int(int a) => a; }));
}

/***************************************************/
// on StructLiteralExp::elements

void test8()
{
    struct S
    {
        int function(int) fp;
    }
    auto s1 = S(a => a);
    static assert(!__traits(compiles, { auto s2 = S((a, b) => a); }));
}

/***************************************************/
// on concat operation

void test9()
{
    int function(int)[] a2;
    a2 ~= x => x;
}

/***************************************************/
// on associative array key

void test10()
{
    int[int function()] aa;
    assert(!aa.remove(() => 1));

    int[int function(int)] aa2;
    assert(!aa2.remove(x => 1));
}

/***************************************************/
// on common type deduction

void test11()
{
    auto a1 = [x => x, (int x) => x * 2];
    static assert(is(typeof(a1[0]) == int function(int) pure @safe nothrow));
    assert(a1[0](10) == 10);
    assert(a1[1](10) == 20);

    //int n = 10;
    //auto a2 = [x => n, (int x) => x * 2];
    //static assert(is(typeof(a2[0]) == int delegate(int) @safe nothrow));
    //assert(a2[0](99) == 10);
    //assert(a2[1](10) == 20);

    int function(int) fp = true ? (x => x) : (x => x*2);
    assert(fp(10) == 10);

    int m = 10;
    int delegate(int) dg = true ? (x => x) : (x => m*2);
    assert(dg(10) == 10);
}

/***************************************************/
// 3235

void test3235()
{
    // from TDPL
    auto f = (int i) {};
    static if (is(typeof(f) _ == F*, F) && is(F == function))
    {} else static assert(0);
}

/***************************************************/
// 6714

void foo6714x(int function (int, int) a){}
void bar6714x(int delegate (int, int) a){}

int bar6714y(double delegate(int, int) a){ return 1; }
int bar6714y(   int delegate(int, int) a){ return 2; }

void test6714()
{
    foo6714x((a, b) { return a + b; });
    bar6714x((a, b) { return a + b; });

    assert(bar6714y((a, b){ return 1.0;  }) == 1);
    static assert(!__traits(compiles, {
           bar6714y((a, b){ return 1.0f; });
    }));
    assert(bar6714y((a, b){ return a;    }) == 2);
}

/***************************************************/
// 7193

void test7193()
{
    static assert(!__traits(compiles, {
        delete a => a;
    }));
}

/***************************************************/
// 7207 : on CastExp

void test7202()
{
    auto dg = cast(int function(int))(a => a);
    assert(dg(10) == 10);
}

/***************************************************/
// 7288

void test7288()
{
    // 7288 -> OK
    auto foo()
    {
        int x;
        return () => { return x; };
    }
    pragma(msg, typeof(&foo));
    alias int delegate() nothrow @safe delegate() nothrow @safe delegate() Dg;
    pragma(msg, Dg);
    static assert(is(typeof(&foo) == Dg));  // should pass
}

/***************************************************/
// 7499

void test7499()
{
    int function(int)[]   a1 = [ x => x ];  // 7499
    int function(int)[][] a2 = [[x => x]];  // +a
    assert(a1[0]   (10) == 10);
    assert(a2[0][0](10) == 10);
}

/***************************************************/
// 7500

void test7500()
{
    alias immutable bool function(int[]) Foo;
    Foo f = a => true;
}

/***************************************************/
// 7525

void test7525()
{
    {
        char[] delegate() a = { return null; };
           int delegate() b = { return 1U; };
          uint delegate() c = { return 1; };
         float delegate() d = { return 1.0; };
        double delegate() e = { return 1.0f; };
    }

    {
        char[] delegate(int) a = (x){ return null; };
           int delegate(int) b = (x){ return 1U; };
          uint delegate(int) c = (x){ return 1; };
         float delegate(int) d = (x){ return 1.0; };
        double delegate(int) e = (x){ return 1.0f; };
    }
}

/***************************************************/
// 7582

void test7582()
{
    void delegate(int) foo;
    void delegate(int) foo2;
    foo = (a) {
        foo2 = (b) { };
    };
}

/***************************************************/
// 7649

void test7649()
{
    void foo(int function(int) fp = x => 1)
    {
        assert(fp(1) == 1);
    }
    foo();
}

/***************************************************/
// 7650

void test7650()
{
    int[int function(int)] aa1 = [x=>x:1, x=>x*2:2];
    foreach (k, v; aa1) {
        if (v == 1) assert(k(10) == 10);
        if (v == 2) assert(k(10) == 20);
    }

    int function(int)[int] aa2 = [1:x=>x, 2:x=>x*2];
    assert(aa2[1](10) == 10);
    assert(aa2[2](10) == 20);

    int n = 10;
    int[int delegate(int)] aa3 = [x=>n+x:1, x=>n+x*2:2];
    foreach (k, v; aa3) {
        if (v == 1) assert(k(10) == 20);
        if (v == 2) assert(k(10) == 30);
    }

    int delegate(int)[int] aa4 = [1:x=>n+x, 2:x=>n+x*2];
    assert(aa4[1](10) == 20);
    assert(aa4[2](10) == 30);
}

/***************************************************/
// 7705

void test7705()
{
    void foo1(void delegate(ref int ) dg){ int x=10; dg(x); }
    foo1((ref x){ pragma(msg, typeof(x)); assert(x == 10); });
    static assert(!__traits(compiles, foo1((x){}) ));

    void foo2(void delegate(int, ...) dg){ dg(20, 3.14); }
    foo2((x,...){ pragma(msg, typeof(x)); assert(x == 20); });

    void foo3(void delegate(int[]...) dg){ dg(1, 2, 3); }
    foo3((x ...){ pragma(msg, typeof(x)); assert(x == [1,2,3]); });
}

/***************************************************/
// 7713

void foo7713(T)(T delegate(in Object) dlg)
{}
void test7713()
{
   foo7713( (in obj) { return 15; } );   // line 6
}

/***************************************************/
// 7743

auto foo7743a()
{
    int x = 10;
    return () nothrow {
        return x;
    };
}
auto foo7743b()
{
    int x = 10;
    return () nothrow => x;
}
void test7743()
{
    static assert(is(typeof(&foo7743a) == int delegate() nothrow @safe function()));
    assert(foo7743a()() == 10);

    static assert(is(typeof(&foo7743b) == int delegate() nothrow @safe function()));
    assert(foo7743b()() == 10);
}

/***************************************************/
// 7761

enum dg7761 = (int a) pure => 2 * a;

void test7761()
{
    static assert(is(typeof(dg7761) == int function(int) pure @safe nothrow));
    assert(dg7761(10) == 20);
}

/***************************************************/
// 7941

void test7941()
{
    static assert(!__traits(compiles, { enum int c = function(){}; }));
}

/***************************************************/
// 8005

void test8005()
{
    auto n = (a, int n = 2){ return n; }(1);
    assert(n == 2);
}

/***************************************************/
// test8198

void test8198()
{
    T delegate(T) zero(T)(T delegate(T) f)
    {
        return x => x;
    }

    T delegate(T) delegate(T delegate(T)) succ(T)(T delegate(T) delegate(T delegate(T)) n)
    {
        return f => x => f(n(f)(x));
    }

    auto n = &zero!uint;
    foreach (i; 0..10)
    {
        assert(n(x => x + 1)(0) == i);
        n = succ(n);
    }
}

/***************************************************/
// 8226

immutable f8226 = (int x) => x * 2;

void test8226()
{
    assert(f8226(10) == 20);
}

/***************************************************/
// 8241

auto exec8241a(alias a = function(x) => x, T...)(T as)
{
    return a(as);
}

auto exec8241b(alias a = (x) => x, T...)(T as)
{
    return a(as);
}

void test8241()
{
    exec8241a(2);
    exec8241b(2);
}

/***************************************************/
// 8242

template exec8242(alias a, T...)
{
    auto func8242(T as)
    {
        return a(as);
    }
}

mixin exec8242!(x => x, int);
mixin exec8242!((string x) => x, string);

void test8242()
{
    func8242(1);
    func8242("");
}

/***************************************************/
// 8315

void test8315()
{
    bool b;
    foo8315!(a => b)();
}

void foo8315(alias pred)()
if (is(typeof(pred(1)) == bool))
{}

/***************************************************/
// 8397

void test8397()
{
    void function(int) f;
  static assert(!is(typeof({
    f = function(string x) {};
  })));
}

/***************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test4v();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test11();
    test3235();
    test6714();
    test7193();
    test7202();
    test7288();
    test7499();
    test7500();
    test7525();
    test7582();
    test7649();
    test7650();
    test7705();
    test7713();
    test7743();
    test7761();
    test7941();
    test8005();
    test8198();
    test8226();
    test8241();
    test8242();
    test8315();
    test8397();

    printf("Success\n");
    return 0;
}
