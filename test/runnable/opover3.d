
void test1()
{
    static struct Foo1
    {
    }

    Foo1 foo1;
    Foo1 foo1_2 = Foo1();   // default ctor call
    static assert(!__traits(compiles, Foo1(1)));

    static assert(!__traits(compiles, foo1()));
    static assert(!__traits(compiles, foo1(1)));
}

/**************************************/

void test2()
{
    static struct Foo2
    {
        this(int n){}
    }

    Foo2 foo2;
    Foo2 foo2_2 = Foo2();       // default ctor call
    Foo2 foo2_3 = Foo2(1);      // user ctor call

    static assert(!__traits(compiles, foo2()));
    static assert(!__traits(compiles, foo2(1)));
}

/**************************************/

void test2a()
{
    static struct Foo2a // alternation of Foo2
    {
        static Foo2a opCall(int n){ Foo2a foo2a; return foo2a; }
    }

    Foo2a foo2a;
    Foo2a foo2a_2 = Foo2a();    // default ctor call
    Foo2a foo2a_3 = Foo2a(1);   // static opCall

    static assert(!__traits(compiles, foo2a()));
    foo2a(1);   // static method call from object
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
    Foo2c foo2c_2 = Foo2c();    // default ctor call
    Foo2c foo2c_3 = Foo2c(1);   // user ctor call
    static assert(!__traits(compiles, Foo2c(1,2))); // static opCall
    // It seems to me that should always conflict with ctor call.
    // Because construction by static opCall is old feature

    static assert(!__traits(compiles, foo2c()));
    static assert(!__traits(compiles, foo2c(1)));
    foo2c(1,2); // static method call from object
    // This should pass.
    // Constructor should not visible from object, so static opCall should match.
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
    Foo3 foo3_2 = Foo3();       // default ctor call
    Foo3 foo3_3 = Foo3(1);      // user ctor call

    static assert(!__traits(compiles, foo3()));
    assert(foo3(1) == 0);       // object opCall
}

/**************************************/

void test3c()
{
    static struct Foo3c
    {
        this(int n){}
        int opCall(int n){ return 0; }
        static Foo3c opCall(int n, int m){ Foo3c foo3c; return foo3c; }
    }

    Foo3c foo3c;
    Foo3c foo3c_2 = Foo3c();    // default ctor call
    Foo3c foo3c_3 = Foo3c(1);   // user ctor call, should not conflict with opCall
    static assert(!__traits(compiles, Foo3c(1,2))); // static opCall
    // It seems to me that should always conflict with ctor call.
    // Because construction by static opCall is old feature

    static assert(!__traits(compiles, foo3c()));
    assert(foo3c(1) == 0);      // opCall
    foo3c(1,2); // static method call from object
}

/**************************************/

void test4()
{
    static struct Foo4
    {
        int opCall(int n){ return 0; }
        static Foo4 opCall(int n, int m){ Foo4 foo4; return foo4; }
    }

    Foo4 foo4;
    Foo4 foo4_2 = Foo4();       // default ctor call
    static assert(!__traits(compiles, Foo4(1)));
    Foo4 foo4_4 = Foo4(1,2);    // static opCall

    static assert(!__traits(compiles, foo4()));
    assert(foo4(1) == 0);       // opCall
    foo4(1,2);  // static method call from object
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
