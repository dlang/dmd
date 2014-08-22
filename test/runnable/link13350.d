extern (C) int printf(const(char*) fmt, ...);

static int foo();

/**********************************/

auto red()()
{
    return foo();
}

void test13350()
{
    int[] data;
    assert(is(typeof(red())));
}

/**********************************/

struct A1(T) { void f1() {} }
struct B1(T) { void f2() {} }

A1!(B1!int) func1()() { return typeof(return).init; }

void test1()
{
    static if (is(typeof(func1()) R : X!(Y), alias X, Y))
    {
        R.init.f1();
        Y.init.f2();
    }
    else
        static assert(0);
}

/**********************************/

struct A2(T) { void f1() { foo(); } }
struct B2(T) { void f2() { foo(); } }

A2!(B2!int) func2()() { return typeof(return).init; }

void test2()
{
    static if (is(typeof(func2())))
    {
    }
    else
        static assert(0);
}

/**********************************/

template A3() { void foo() { B3!().bar(); } }
template B3() { void bar() {} }

void test3()
{
    // A3!() and B3!() are marked as 'speculative'
    static assert(is(typeof(A3!().foo())));

    // A3!() is unspeculative, but B3!() isn't.
    A3!().foo();

    // in codegen phase, B3!() will generate its members, because
    // the tinst chain contains unspeculative instance A3!().
}

/**********************************/

struct S4(T)
{
    string toString() const { return "instantiated"; }
}

void test4()
{
    // inside typeof is not speculative context
    alias X = typeof(S4!int());
    assert(typeid(X).xtoString !is null);
}

/**********************************/

struct S5(T)
{
    string toString() const { return "instantiated"; }
}

void test5()
{
    enum x = S5!int();
    assert(x.toString() == "instantiated");
}

/**********************************/

int main()
{
    test13350();
    test1();
    test2();
    test3();
    test4();
    test5();

    printf("Success\n");
    return 0;
}
