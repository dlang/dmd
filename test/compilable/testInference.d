
/***************************************************/
// 6265.

pure nothrow @safe int h6265() {
    return 1;
}
int f6265a(alias g)() {
    return g();
}
pure nothrow @safe int i6265a() {
    return f6265a!h6265();
}

int f6265b()() {
    return h6265();
}
pure nothrow @safe int i6265b() {
    return f6265b();
}

pure nothrow @safe int i6265c() {
    return {
        return h6265();
    }();
}

/***************************************************/
// Make sure a function is not infered as pure if it isn't.

int fNPa() {
    return 1;
}
int gNPa()() {
    return fNPa();
}
static assert( __traits(compiles, function int ()         { return gNPa(); }));
static assert(!__traits(compiles, function int () pure    { return gNPa(); }));
static assert(!__traits(compiles, function int () nothrow { return gNPa(); }));
static assert(!__traits(compiles, function int () @safe   { return gNPa(); }));

/***************************************************/
// Need to ensure the comment in Expression::checkPurity is not violated.

void fECPa() {
    void g()() {
        void h() {
        }
        h();
    }
    static assert( is(typeof(&g!()) == void delegate() pure nothrow @safe));
    static assert(!is(typeof(&g!()) == void delegate()));
}

void fECPb() {
    void g()() {
        void h() {
        }
        fECPb();
    }
    static assert(!is(typeof(&g!()) == void delegate() pure));
    static assert( is(typeof(&g!()) == void delegate()));
}

/***************************************************/
// 5936

auto bug5936c(R)(R i) @safe pure nothrow {
    return true;
}
static assert( bug5936c(0) );

/***************************************************/
// 6351

void bug6351(alias dg)()
{
    dg();
}

void test6351()
{
    void delegate(int[] a...) deleg6351 = (int[] a...){};
    alias bug6351!(deleg6351) baz6531;
}

/***************************************************/
// 7017

template map7017(fun...) if (fun.length >= 1)
{
    auto map7017()
    {
        struct Result {
            this(int dummy){}   // impure member function -> inferred to pure by fixing issue 10329
        }
        return Result(0);   // impure call -> inferred to pure by fixing issue 10329
    }
}

int foo7017(immutable int x) pure nothrow { return 1; }

void test7017a() pure
{
    int bar7017(immutable int x) pure nothrow { return 1; }

    static assert(__traits(compiles, map7017!((){})()));
    static assert(__traits(compiles, map7017!q{ 1 }()));
    static assert(__traits(compiles, map7017!foo7017()));
    static assert(__traits(compiles, map7017!bar7017()));
}

/***************************************************/
// 7017 (little simpler cases)

auto map7017a(alias fun)() { return fun();     }    // depends on purity of fun
auto map7017b(alias fun)() { return;           }    // always pure
auto map7017c(alias fun)() { return yyy7017(); }    // always impure

int xxx7017() pure { return 1; }
int yyy7017() { return 1; }

void test7017b() pure
{
    static assert( __traits(compiles, map7017a!xxx7017() ));
    static assert(!__traits(compiles, map7017a!yyy7017() ));

    static assert( __traits(compiles, map7017b!xxx7017() ));
    static assert( __traits(compiles, map7017b!yyy7017() ));

    static assert(!__traits(compiles, map7017c!xxx7017() ));
    static assert(!__traits(compiles, map7017c!yyy7017() ));
}

/***************************************************/
// Test case from std.process

auto escapeArgumentImpl(alias allocator)()
{
    return allocator();
}

auto escapeShellArgument(alias allocator)()
{
    return escapeArgumentImpl!allocator();
}

pure string escapeShellArguments()
{
    char[] allocator()
    {
        return new char[1];
    }

    /* Both escape!allocator and escapeImpl!allocator are impure,
     * but they are nested template function that instantiated here.
     * Then calling them from here doesn't break purity.
     */
    return escapeShellArgument!allocator();
}

/***************************************************/
// 8504

void foo8504()()
{
    static assert(typeof(foo8504!()).stringof == "void()");
    static assert(typeof(foo8504!()).mangleof == "FZv");
    static assert(foo8504!().mangleof == "_D13testInference12__T7foo8504Z7foo8504FZv");
}

auto toDelegate8504a(F)(auto ref F fp) { return fp; }
   F toDelegate8504b(F)(auto ref F fp) { return fp; }

extern(C) void testC8504() {}

void test8504()
{
    static assert(typeof(foo8504!()).stringof == "pure nothrow @safe void()");
    static assert(typeof(foo8504!()).mangleof == "FNaNbNfZv");
    static assert(foo8504!().mangleof == "_D13testInference12__T7foo8504Z7foo8504FNaNbNfZv");

    auto fp1 = toDelegate8504a(&testC8504);
    auto fp2 = toDelegate8504b(&testC8504);
    static assert(is(typeof(fp1) == typeof(fp2)));
    static assert(typeof(fp1).stringof == "extern (C) void function()");
    static assert(typeof(fp2).stringof == "extern (C) void function()");
    static assert(typeof(fp1).mangleof == "PUZv");
    static assert(typeof(fp2).mangleof == "PUZv");
}

/***************************************************/
// 8751

alias bool delegate(in int) pure Bar8751;
Bar8751 foo8751a(immutable int x) pure
{
    return y => x > y; // OK
}
Bar8751 foo8751b(const int x) pure
{
    return y => x > y; // error -> OK
}

/***************************************************/
// 8793

alias bool delegate(in int) pure Dg8793;
alias bool function(in int) pure Fp8793;

Dg8793 foo8793fp1(immutable Fp8793 f) pure { return x => (*f)(x); } // OK
Dg8793 foo8793fp2(    const Fp8793 f) pure { return x => (*f)(x); } // OK

Dg8793 foo8793dg1(immutable Dg8793 f) pure { return x => f(x); } // OK
Dg8793 foo8793dg2(    const Dg8793 f) pure { return x => f(x); } // error -> OK

Dg8793 foo8793pfp1(immutable Fp8793* f) pure { return x => (*f)(x); } // OK
Dg8793 foo8793pdg1(immutable Dg8793* f) pure { return x => (*f)(x); } // OK

// general case for the hasPointer type
Dg8793 foo8793ptr1(immutable int* p) pure { return x => *p == x; } // OK

/***************************************************/
// 9072

struct A9072(T)
{
    this(U)(U x) {}
    ~this() {}
}
void test9072()
{
    A9072!int a = A9072!short();
}

/***************************************************/
// 5933 + Issue 8504 - Template attribute inferrence doesn't work

int foo5933()(int a) { return a*a; }
struct S5933
{
    double foo()(double a) { return a * a; }
}
// outside function
static assert(typeof(foo5933!()).stringof == "pure nothrow @safe int(int a)");
static assert(typeof(S5933.init.foo!()).stringof == "pure nothrow @safe double(double a)");

void test5933()
{
    // inside function
    static assert(typeof(foo5933!()).stringof == "pure nothrow @safe int(int a)");
    static assert(typeof(S5933.init.foo!()).stringof == "pure nothrow @safe double(double a)");
}

/***************************************************/
// 10002

void impure10002() {}
void remove10002(alias pred, bool impure = false, Range)(Range range)
{
    pred(range[0]);
    static if (impure) impure10002();
}
class Node10002
{
    Node10002 parent;
    Node10002[] children;

    void foo() pure
    {
        parent.children.remove10002!(n => n is parent)();
        remove10002!(n => n is parent)(parent.children);
        static assert(!__traits(compiles, parent.children.remove10002x!(n => n is parent, true)()));
        static assert(!__traits(compiles, remove10002x!(n => n is parent, true)(parent.children)));

        Node10002 p;
        p.children.remove10002!(n => n is p)();
        remove10002!(n => n is p)(p.children);
        static assert(!__traits(compiles, p.children.remove10002x!(n => n is p, true)()));
        static assert(!__traits(compiles, remove10002x!(n => n is p, true)(p.children)));
    }
}

/***************************************************/
// 10148

void fa10148() {}  // fa is @system

auto fb10148(T)()
{
    struct A(S)
    {
        // [4] Parent function fb is already inferred to @safe, then
        // fc is forcely marked @safe on default until 2.052.
        // But fc should keep attribute inference ability
        // by overriding the inherited @safe-ty from its parent.
        void fc(T2)()
        {
            // [5] During semantic3 process, fc is not @safe on default.
            static assert(is(typeof(&fc) == void delegate()));
            fa10148();
        }
        // [1] this is now inferred to @safe by implementing issue 7511
        this(S a) {}
    }

    // [2] A!int(0) is now calling @safe function, then fb!T also be inferred to @safe
    return A!int(0);
}

void test10148()
{
    fb10148!int.fc!int;  // [0] instantiate fb
                         // [3] instantiate fc

    // [6] Afer semantic3 done, fc!int is deduced to @system.
    static assert(is(typeof(&fb10148!int.fc!int) == void delegate() @system));
}

/***************************************************/
// 10289

void test10289()
{
    void foo(E)()
    {
        throw new E("");
    }
    void bar(E1, E2)()
    {
        throw new E1("");
        throw new E2("");
    }
    void baz(E1, E2)(bool cond)
    {
        if (cond)
            throw new E1("");
        else
            throw new E2("");
    }

    import core.exception;
    static class MyException : Exception
    {
        this(string) @safe pure nothrow { super(""); }
    }

    static assert( __traits(compiles, () nothrow { foo!Error(); }));
    static assert( __traits(compiles, () nothrow { foo!AssertError(); }));

    static assert(!__traits(compiles, () nothrow { foo!Exception(); }));
    static assert(!__traits(compiles, () nothrow { foo!MyException(); }));

    static assert( __traits(compiles, () nothrow { bar!(Error, Exception)(); }));
    static assert(!__traits(compiles, () nothrow { bar!(Exception, Error)(); }));

    static assert(!__traits(compiles, () nothrow { baz!(Error, Exception)(); }));
    static assert(!__traits(compiles, () nothrow { baz!(Exception, Error)(); }));
}

/***************************************************/
// 10296

void foo10296()()
{
    int[3] a;

    void bar()() { a[1] = 2; }
    bar();
    pragma(msg, typeof(bar!()));    // nothrow @safe void()
}
pure void test10296()
{
    foo10296();
}

/***************************************************/

// Add more tests regarding inferences later.

