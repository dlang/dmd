// PERMUTE_ARGS: -property

extern (C) int printf(const char* fmt, ...);

// Is -property option specified?
enum enforceProperty = !__traits(compiles, {
    int prop(){ return 1; }
    int n = prop;
});

/*******************************************/

template select(alias v1, alias v2)
{
    static if (enforceProperty)
        enum select = v1;
    else
        enum select = v2;
}

struct Test(int N)
{
    int value;
    int getset;

    static if (N == 0)
    {
        ref foo(){ getset = 1; return value; }

        enum result = select!(0, 1);
        // -property    test.d(xx): Error: not a property foo
        // (no option)  prints "getter"
    }
    static if (N == 1)
    {
        ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 2);
        // -property    test.d(xx): Error: not a property foo
        // (no option)  prints "setter"
    }
    static if (N == 2)
    {
        @property ref foo(){ getset = 1; return value; }

        enum result = select!(1, 1);
        // -property    prints "getter"
        // (no option)  prints "getter"
    }
    static if (N == 3)
    {
        @property ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(2, 2);
        // -property    prints "setter"
        // (no option)  prints "setter"
    }


    static if (N == 4)
    {
        ref foo()     { getset = 1; return value; }
        ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 2);
        // -property    test.d(xx): Error: not a property foo
        // (no option)  prints "setter"
    }
    static if (N == 5)
    {
        @property ref foo()     { getset = 1; return value; }
                  ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 0);
        // -property    test.d(xx): Error: cannot overload both property and non-property functions
        // (no option)  test.d(xx): Error: cannot overload both property and non-property functions
    }
    static if (N == 6)
    {
                  ref foo()     { getset = 1; return value; }
        @property ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(0, 0);
        // -property    test.d(xx): Error: cannot overload both property and non-property functions
        // (no option)  test.d(xx): Error: cannot overload both property and non-property functions
    }
    static if (N == 7)
    {
        @property ref foo()     { getset = 1; return value; }
        @property ref foo(int x){ getset = 2; value = x; return value; }

        enum result = select!(2, 2);
        // -property    prints "setter"
        // (no option)  prints "setter"
    }
}

template seq(T...)
{
    alias T seq;
}
template iota(int begin, int end)
    if (begin <= end)
{
    static if (begin == end)
        alias seq!() iota;
    else
        alias seq!(begin, iota!(begin+1, end)) iota;
}

void test1()
{
    foreach (N; iota!(0, 8))
    {
        printf("%d: ", N);

        Test!N s;
        static if (Test!N.result == 0)
        {
            static assert(!is(typeof({ s.foo = 1; })));
            printf("compile error\n");
        }
        else
        {
            s.foo = 1;
            if (s.getset == 1)
                printf("getter\n");
            else
                printf("setter\n");
            assert(s.getset == Test!N.result);
        }
    }
}

/*******************************************/
// 7722

class Foo7722 {}
void spam7722(Foo7722 f) {}

void test7722()
{
    auto f = new Foo7722;
    static if (enforceProperty)
        static assert(!__traits(compiles, f.spam7722));
    else
        f.spam7722;
}

/*******************************************/

@property void check(alias v1, alias v2, alias dg)()
{
    void checkImpl(alias v)()
    {
        static if (v == 0)
            static assert(!__traits(compiles, dg(0)));
        else
            assert(dg(0) == v);
    }

    static if (enforceProperty)
        checkImpl!(v1)();
    else
        checkImpl!(v2)();
}

struct S {}

int foo(int n)          { return 1; }
int foo(int n, int m)   { return 2; }
int goo(int[] a)        { return 1; }
int goo(int[] a, int m) { return 2; }
int bar(S s)            { return 1; }
int bar(S s, int n)     { return 2; }

int baz(X)(X x)         { return 1; }
int baz(X)(X x, int n)  { return 2; }

int temp;
ref int boo(int n)      { return temp; }
ref int coo(int[] a)    { return temp; }
ref int mar(S s)        { return temp; }

ref int maz(X)(X x)     { return temp; }

void test7722a()
{
    int n;
    int[] a;
    S s;

    check!(1, 1, x =>    foo(4)     );      check!(1, 1, x =>    baz(4)     );
    check!(1, 1, x =>  4.foo()      );      check!(1, 1, x =>  4.baz()      );
    check!(0, 1, x =>  4.foo        );      check!(0, 1, x =>  4.baz        );
    check!(2, 2, x =>    foo(4, 2)  );      check!(2, 2, x =>    baz(4, 2)  );
    check!(2, 2, x =>  4.foo(2)     );      check!(2, 2, x =>  4.baz(2)     );
    check!(0, 2, x => (4.foo = 2)   );      check!(0, 2, x => (4.baz = 2)   );

    check!(1, 1, x =>    goo(a)     );      check!(1, 1, x =>    baz(a)     );
    check!(1, 1, x =>  a.goo()      );      check!(1, 1, x =>  a.baz()      );
    check!(0, 1, x =>  a.goo        );      check!(0, 1, x =>  a.baz        );
    check!(2, 2, x =>    goo(a, 2)  );      check!(2, 2, x =>    baz(a, 2)  );
    check!(2, 2, x =>  a.goo(2)     );      check!(2, 2, x =>  a.baz(2)     );
    check!(0, 2, x => (a.goo = 2)   );      check!(0, 2, x => (a.baz = 2)   );

    check!(1, 1, x =>    bar(s)     );      check!(1, 1, x =>    baz(s)     );
    check!(1, 1, x =>  s.bar()      );      check!(1, 1, x =>  s.baz()      );
    check!(0, 1, x =>  s.bar        );      check!(0, 1, x =>  s.baz        );
    check!(2, 2, x =>    bar(s, 2)  );      check!(2, 2, x =>    baz(s, 2)  );
    check!(2, 2, x =>  s.bar(2)     );      check!(2, 2, x =>  s.baz(2)     );
    check!(0, 2, x => (s.bar = 2)   );      check!(0, 2, x => (s.baz = 2)   );

    check!(2, 2, x => (  boo(4) = 2));      check!(2, 2, x => (  maz(4) = 2));
    check!(0, 2, x => (4.boo    = 2));      check!(0, 2, x => (4.maz    = 2));
    check!(2, 2, x => (  coo(a) = 2));      check!(2, 2, x => (  maz(a) = 2));
    check!(0, 2, x => (a.coo    = 2));      check!(0, 2, x => (a.maz    = 2));
    check!(2, 2, x => (  mar(s) = 2));      check!(2, 2, x => (  maz(s) = 2));
    check!(0, 2, x => (s.mar    = 2));      check!(0, 2, x => (s.maz    = 2));
}

int hoo(T)(int n)          { return 1; }
int hoo(T)(int n, int m)   { return 2; }
int koo(T)(int[] a)        { return 1; }
int koo(T)(int[] a, int m) { return 2; }
int var(T)(S s)            { return 1; }
int var(T)(S s, int n)     { return 2; }

int vaz(T, X)(X x)         { return 1; }
int vaz(T, X)(X x, int n)  { return 2; }

//int temp;
ref int voo(T)(int n)      { return temp; }
ref int woo(T)(int[] a)    { return temp; }
ref int nar(T)(S s)        { return temp; }

ref int naz(T, X)(X x)     { return temp; }

void test7722b()
{
    int n;
    int[] a;
    S s;

    check!(1, 1, x =>    hoo!int(4)     );  check!(1, 1, x =>    vaz!int(4)     );
    check!(1, 1, x =>  4.hoo!int()      );  check!(1, 1, x =>  4.vaz!int()      );
    check!(0, 1, x =>  4.hoo!int        );  check!(0, 1, x =>  4.vaz!int        );
    check!(2, 2, x =>    hoo!int(4, 2)  );  check!(2, 2, x =>    vaz!int(4, 2)  );
    check!(2, 2, x =>  4.hoo!int(2)     );  check!(2, 2, x =>  4.vaz!int(2)     );
    check!(0, 2, x => (4.hoo!int = 2)   );  check!(0, 2, x => (4.vaz!int = 2)   );

    check!(1, 1, x =>    koo!int(a)     );  check!(1, 1, x =>    vaz!int(a)     );
    check!(1, 1, x =>  a.koo!int()      );  check!(1, 1, x =>  a.vaz!int()      );
    check!(0, 1, x =>  a.koo!int        );  check!(0, 1, x =>  a.vaz!int        );
    check!(2, 2, x =>    koo!int(a, 2)  );  check!(2, 2, x =>    vaz!int(a, 2)  );
    check!(2, 2, x =>  a.koo!int(2)     );  check!(2, 2, x =>  a.vaz!int(2)     );
    check!(0, 2, x => (a.koo!int = 2)   );  check!(0, 2, x => (a.vaz!int = 2)   );

    check!(1, 1, x =>    var!int(s)     );  check!(1, 1, x =>    vaz!int(s)     );
    check!(1, 1, x =>  s.var!int()      );  check!(1, 1, x =>  s.vaz!int()      );
    check!(0, 1, x =>  s.var!int        );  check!(0, 1, x =>  s.vaz!int        );
    check!(2, 2, x =>    var!int(s, 2)  );  check!(2, 2, x =>    vaz!int(s, 2)  );
    check!(2, 2, x =>  s.var!int(2)     );  check!(2, 2, x =>  s.vaz!int(2)     );
    check!(0, 2, x => (s.var!int = 2)   );  check!(0, 2, x => (s.vaz!int = 2)   );

    check!(2, 2, x => (  voo!int(4) = 2));  check!(2, 2, x => (  naz!int(4) = 2));
    check!(0, 2, x => (4.voo!int    = 2));  check!(0, 2, x => (4.naz!int    = 2));
    check!(2, 2, x => (  woo!int(a) = 2));  check!(2, 2, x => (  naz!int(a) = 2));
    check!(0, 2, x => (a.woo!int    = 2));  check!(0, 2, x => (a.naz!int    = 2));
    check!(2, 2, x => (  nar!int(s) = 2));  check!(2, 2, x => (  naz!int(s) = 2));
    check!(0, 2, x => (s.nar!int    = 2));  check!(0, 2, x => (s.naz!int    = 2));
}

/*******************************************/

int main()
{
    test1();
    test7722();
    test7722a();
    test7722b();

    printf("Success\n");
    return 0;
}
