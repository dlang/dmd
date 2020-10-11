module member_alias;

// set, get, identity, address of alias to local static array elem
void test1()
{
    int[2] a = [1,2];
    alias a1 = a[1];
    assert(a1 == 2);
    a1 = 42;
    assert(a1 == 42);
    assert(a1 == a[1]);
    assert(a1 is a[1]);
    assert(&a1 is &a[1]);
}

// set, get, identity, address of alias to global static array elem
void test2()
{
    static int[2] a = [1,2];
    alias a1 = a[1];
    assert(a1 == 2);
    a1 = 42;
    assert(a1 == 42);
    assert(a1 == a[1]);
    assert(a1 is a[1]);
    assert(&a1 is &a[1]);
}

// set, get, identity, address of alias to local dyn array elem
void test3()
{
    int[] a = [1,2];
    alias a1 = a[1];
    assert(a1 == 2);
    a1 = 42;
    assert(a1 == 42);
    assert(a1 == a[1]);
    assert(a1 is a[1]);
    assert(&a1 is &a[1]);
}

// set, get, from custom type w/ opover
void test4()
{
    static struct Foo
    {
        string field = "42";
        ref opIndex(T)(T)
        {
            return field;
        }
    }
    Foo foo;
    alias f1 = foo[1];
    assert(f1 == "42");
    f1 = "1337";
    assert(f1 == "1337");
    assert(foo.field == "1337");
}

// check for symbol conflict in different scopes
int[2] c = [3,4];
alias c0 = c[0];
void test5()
{
    int[2] c = [101,202];
    assert (c0 == 3);
    c0 = 5;
    assert (c[0] == 101);
    assert (.c[0] == 5);
}

// indexed symbol is firstly indexed from a tuple
void test6()
{
    alias Seq(T...) = T;
    int[2] a = [0,1];
    int[2] b = [2,3];
    alias ab = Seq!(a,b);
    alias a0 = ab[0][0];
    alias a1 = ab[0][1];
    alias b0 = ab[1][0];
    alias b1 = ab[1][1];
    assert(a0 == 0);
    assert(a1 == 1);
    assert(b0 == 2);
    assert(b1 == 3);
}

// CTFE index
void test7()
{
    static int index(){return 0;}
    int[1] a = [123];
    alias a0 = a[index()];
    assert(a0 == 123);
}

// templatized alias
void test8()
{
    int[2] a = [0,1];
    alias accesElemOne(alias array) = array[0];
    alias accesElemTwo(alias array) = array[1];
    assert(accesElemOne!(a) == 0);
    assert(accesElemTwo!(a) == 1);
    alias acces(alias array, int index) = array[index];
    assert(acces!(a,1) == 1);
}

// alias of the alias of the symbol created to tie the var to an index
void test9()
{
    int[2] a = [0,1];
    alias a1 = a[1];
    alias aa1 = a1;
    assert(aa1 == 1);
}

// use aliases instead of getters to extract RGBA components
void test10()
{
    static struct Color
    {
        uint rgba;
        ubyte opIndex(uint index)
        in(index < 4)
        {
            return *((cast(ubyte*) &rgba) + index);
        }
    }
    Color c = Color(0xDDCCEE00);
    alias a = c[0];
    alias r = c[1];
    alias g = c[2];
    alias b = c[3];
    assert(a == 0);
    assert(r == 0xEE);
    assert(g == 0xCC);
    assert(b == 0xDD);
}

// fully operating in CTFE
void test11()
{
    static int get()
    {
        int[8] a;
        a[7] = 42;
        alias result = a[7];
        return result;
    }
    static assert(get() == 42);
}

// array literal allowed for enum
void test12()
{
    enum int[1] a = [1];
    alias a0 = a[0];
    static assert (a0 == 1);
}

// template params, typeof
void test13()
{
    enum E { one, two, three }
    static immutable E[3] e = [E.one, E.two, E.three];
    alias e2 = e[1];

    template T1(alias tp)   { static assert(tp == E.two); }
    template T2(int tp)     { static assert(tp == E.two); }
    template T3(A...)       { static assert(A[0] == E.two); }
    template T4(T)          { static assert(is(T == immutable(E))); }
    alias T1e2 = T1!e2;
    alias T2e2 = T2!e2;
    alias T3e2 = T3!e2;
    alias T4e2 = T4!(typeof(e2));
}


// IFTI
void iftiFunc(T)(ref T t){ static assert(is(T == int)); t = 42; }
void test15()
{
    int[1] a;
    alias a0 = a[0];
    a0.iftiFunc();
    assert(a[0] == 42);
}

// member VarDeclaration alias
void test16()
{
    static struct S { int i; }
    S s1 = S(1);
    S s2 = S(2);
    alias s1i = s1.i;
    alias s2i = s2.i;
    assert(s1i == 1);
    assert(s2i == 2);
    s1i = 42;
    s2i = 1337;
    assert(s1.i == 42);
    assert(s2.i == 1337);
}

// member FuncDeclaration alias
void test17()
{
    static struct S { int i;  ref int get() return {return i;} }
    S s1 = S(1);
    S s2 = S(2);
    alias s1i = s1.get;
    alias s2i = s2.get;
    assert(s1i == 1);
    assert(s2i == 2);
    s1i = 42;
    s2i = 1337;
    assert(s1.i == 42);
    assert(s2.i == 1337);
}

// used to break the test suite in bigger test file, so extracted here
void funcBreakers1()
{
    static class A
    {
        void foo(){}
    }
    static class B : A
    {
        alias foo = A.foo;
    }
    static class C
    {
        void foo(){}
        void foo(uint){}
    }
    static class D : C
    {
        alias foo = C.foo;
    }
}

// used to break the test suite in bigger test file, so extracted here
mixin template M1()
{
    auto get()
    {
        return this;
    }
}
void funcBreakers2()
{
    static struct S
    {
        mixin M1 m;
        alias get = m.get;
    }

    S s;
    assert(s.get is s);
}

// used to break the test suite in bigger test file, so extracted here
void funcBreakers3()
{
    template T()
    {
        static int get()
        {
            return 0;
        }
    }

    static struct S(alias tp)
    {
        alias get = tp.get;
    }

    S!(T!()) s;
    assert(s.get() == 0);
}

void test14128()
{
    static struct Foo
    {
        int v;
        void test(Foo that) const
        {
            alias a = this.v;
            alias b = that.v;
            assert (&a !is &b);
        }
    }
    Foo a = Foo(1);
    Foo b = Foo(2);
    a.test(b);
}

void main()
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
    test12();
    test15();
    test16();
    test17();
    test14128();
    funcBreakers2();
    funcBreakers3();
}
