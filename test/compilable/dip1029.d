
void foo() {}

void foobar() throw {}
void bar() nothrow {}

nothrow {
    void n_t() throw;
    void n();
}

void _t();
void t() throw;


struct S {
    void foo() {
        _t();
        t();
        n_t();
    }
}

static assert(is(typeof(&S.foo) == void function()));

// class inheritance
class CA {
    void foo() throw;
}

class CB : CA {
    override void foo() @nogc;
}

static assert(is(typeof(&CA.foo) == void function() throw));
static assert(is(typeof(&CB.foo) == void function() throw @nogc));


// inferred types and attributes for lambdas
static assert(is(typeof(() {}) == void function() pure nothrow @nogc @safe));
static assert(is(typeof(() { throw new Exception(""); }) == void function() pure @safe));
static assert(is(typeof(function() throw { throw new Exception(""); }) == void function() pure throw @safe));

// check if default throw is the same as with explicit throw
static assert(is(void function() pure throw @safe == void function() pure @safe));

auto abc()
{
    int localvar;
    static assert(is(typeof(() => localvar) == int delegate() pure nothrow @nogc @safe));
    static assert(is(typeof(delegate() throw => localvar) == int delegate() pure throw @nogc @safe));

    return localvar;
}

// check if functions has correct types
static assert(is(typeof(&foo) == void function()));
static assert(is(typeof(&foobar) == void function() throw));
static assert(is(typeof(&bar) == void function() nothrow));
static assert(is(typeof(&n_t) == void function() throw));
static assert(is(typeof(&n) == void function() nothrow));
static assert(is(typeof(&_t) == void function()));
static assert(is(typeof(&t) == void function() throw));
static assert(is(typeof(&t2) == void function() throw));
static assert(is(typeof(&n2) == void function() nothrow));

void funcDefault() @system pure @nogc;
void funcThrow() @system pure @nogc throw;
void funcNothrow() @system pure @nogc nothrow;

// test getFunctionAttributes
static assert([__traits(getFunctionAttributes, funcDefault)] == ["pure", "throw", "@nogc", "@system"]);
static assert([__traits(getFunctionAttributes, funcThrow)] == ["pure", "throw", "@nogc", "@system"]);
static assert([__traits(getFunctionAttributes, funcNothrow)] == ["pure", "nothrow", "@nogc", "@system"]);

void func()
{
    alias FnT = void function() throw;
    alias FnN = void function() nothrow;

    FnN fnn = () {};
    FnT fnt = () { throw new Exception(""); };

    static assert(!__traits(compiles, { fnn = fnt; })); // throw -> nothrow
    static assert(__traits(compiles, { fnt = fnn; }));  // nothrow -> throw
}

// check template inference
void funcNothrowT()() {}
static assert(is(typeof(&funcNothrowT!()) == void function() nothrow @nogc @safe pure));
void funcExplicitThrowT()() throw {}
static assert(is(typeof(&funcExplicitThrowT!()) == void function() throw @nogc @safe pure));
// should be the same without throw
static assert(is(typeof(&funcExplicitThrowT!()) == void function() @nogc @safe pure));

void funcThrowT()() {
    throw new Exception("");
}
static assert(is(typeof(&funcThrowT!()) == void function() throw @safe pure));
// should be the same without throw
static assert(is(typeof(&funcThrowT!()) == void function() @safe pure));


nothrow:
    void t2() throw;

throw:
    void n2() nothrow;

