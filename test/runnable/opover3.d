
void test1()
{
    static struct Foo1
    {
    }

    Foo1 foo1;
    Foo1 foo1_2 = Foo1();       // literal syntax

    static assert(!__traits(compiles, foo1()));
}

/**************************************/

void test2()
{
    static struct Foo2
    {
        this(int n){}
    }

    Foo2 foo2;
    Foo2 foo2_2 = Foo2(1);      // user ctor call
    Foo2 foo2_3 = Foo2();       // literal syntax

    static assert(!__traits(compiles, foo2(1)));
    static assert(!__traits(compiles, foo2()));
}

/**************************************/

void test2a()
{
    static struct Foo2a // alternation of Foo2
    {
        static Foo2a opCall(int n){ Foo2a foo2a; return foo2a; }
    }

    Foo2a foo2a;
    Foo2a foo2a_3 = Foo2a(1);                       // static opCall
    static assert(!__traits(compiles, Foo2a()));    // static opCall hides literal syntax.

    foo2a(1);                                       // static opCall from instance
    static assert(!__traits(compiles, foo2a()));
}

/**************************************/

void test2c()
{
    static struct Foo2c // conflict version
    {
        this(int n){}
        static Foo2c opCall(int n, int m){ Foo2c foo2c; return foo2c; }
    }

    Foo2c foo2c;
    Foo2c foo2c_3 = Foo2c(1);                       // user ctor call
    static assert(!__traits(compiles, Foo2c(1,2))); // user ctor hides static opCall.
    static assert(!__traits(compiles, Foo2c()));    // static opCall hides literal syntax.

    static assert(!__traits(compiles, foo2c(1)));
    foo2c(1,2);                                     // static opCall from instance
    static assert(!__traits(compiles, foo2c()));
}

/**************************************/

void test3()
{
    static struct Foo3
    {
        this(int n){}
        int opCall(int n){ return 0; }
    }

    Foo3 foo3;
    Foo3 foo3_3 = Foo3(1);                          // user ctor call
    static assert(!__traits(compiles, Foo3()));     // instance opCall hides literal syntax...right?

    assert(foo3(1) == 0);                           // instance opCall
    static assert(!__traits(compiles, foo3()));
}

/**************************************/

void test3c()
{
    static struct Foo3c
    {
        this(int n){}
        static Foo3c opCall(int n, int m){ Foo3c foo3c; return foo3c; }
        int opCall(int n){ return 0; }
    }

    Foo3c foo3c;
    Foo3c foo3c_3 = Foo3c(1);                       // user ctor call
    static assert(!__traits(compiles, Foo3c(1,2))); // user ctor hides static opCall
    static assert(!__traits(compiles, Foo3c()));    // static opCall hides literal syntax

    assert(foo3c(1,2) == Foo3c.init);               // static opCall from instance
    assert(foo3c(1) == 0);                          // instance opCall
    static assert(!__traits(compiles, foo3c()));
}

/**************************************/

void test4()
{
    static struct Foo4
    {
        static Foo4 opCall(int n, int m){ Foo4 foo4; return foo4; }
        int opCall(int n){ return 0; }
    }

    Foo4 foo4;
    Foo4 foo4_4 = Foo4(1,2);                        // static opCall
    static assert(!__traits(compiles, Foo4(1)));
    static assert(!__traits(compiles, Foo4()));     // static opCall hides literal syntax

    assert(foo4(1,2) == Foo4.init);                 // static opCall from instance
    assert(foo4(1) == 0);                           // instance opCall
    static assert(!__traits(compiles, foo4()));
}

/**************************************/

void main()
{
    test1();
    test2();
    test2a();
    test2c();
    test3();
    test3c();
    test4();
}
