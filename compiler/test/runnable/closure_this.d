/* REQUIRED_ARGS: -betterC
   PERMUTE_ARGS: -O -inline -release -g
 */

/* A nested function inside a member function that captures nothing from the
 * enclosing frame other than `this` gets `this` as its context pointer, like
 * an anonymous member function. No closure is allocated, which -betterC
 * verifies: a closure allocation is a compile error.
 */

struct S
{
@nogc:

    int x = 10;
    int y = 20;
    int delegate() saved;

    int delegate() getX() { return () => x; }
    int delegate(int) addY() { return (int a) => a + y; }

    int delegate() viaNamed()
    {
        int bar() { return x * y; }
        return &bar;
    }

    // two this-only siblings; baz forwards its context to bar
    int delegate() siblings()
    {
        int bar() { return x; }
        int baz() { return bar() + y; }
        return &baz;
    }

    // this-only lambda calling a sibling that captures nothing
    int delegate() indifferent()
    {
        int h() { return 1; }
        return () => x + h();
    }

    // lambda in a lambda, both only using `this`
    int delegate() nested()
    {
        return () { auto inner = () => x + 1; return inner() + y; };
    }

    // inner lambda uses the outer lambda's local and `this`
    int delegate() deep()
    {
        return () { int k = 5; return (() => x + k)(); };
    }

    // three levels deep, each level only naming `this`
    int delegate() threeDeep()
    {
        return () {
            int delegate() @nogc mid() { return () => x; }
            return mid()() + y;
        };
    }

    // the innermost delegate escapes through every level
    int delegate() threeDeepEscape()
    {
        int delegate() outer()
        {
            int delegate() mid() { return () => x * 3; }
            return mid();
        }
        return outer();
    }

    // the intermediate levels have locals of their own, used by the innermost
    int delegate() threeDeepLocals()
    {
        return () {
            int k = 1;
            return (() {
                int m = 2;
                return (() => x + k + m)();
            })();
        };
    }

    // this-only lambda next to a frame-using sibling that is called directly
    int delegate() mixed()
    {
        int local = 3;
        int g() { return local; }
        y = g();
        return () => x + y;
    }

    // f itself only touches `this`, but calling g makes it need the frame too
    int propagate()
    {
        int local = 1;
        int g() { return local; }
        int f() { return x + g(); }
        return f();
    }

    // g uses a local and calls this-only f: g must hand f `this`
    int reverse()
    {
        int local = 1;
        int f() { return x; }
        int g() { return local + f(); }
        return g();
    }

    // non-escaping nested function using `this`
    int direct()
    {
        int bar() { return x * 2; }
        return bar();
    }

    // a sibling that references nothing itself but calls a this-only function
    // takes `this` as its context too, so that it has it to pass on; it can
    // then escape as well, with no frame behind it
    int delegate() wrapper(int local)
    {
        int read() { return x; }
        int wrap() { return read(); }
        int touch() { return local; }
        x += touch();
        return &wrap;
    }

    int sum() const { return x + y; }
    int delegate() callsMember() { return () => sum(); }

    void delegate() bump() { return () { x++; }; }

    // escapes into a member, invoked after the method returned
    void save() { saved = () => x + y; }

    this(int v) { x = v; saved = () => x; }

    auto cget() const { return () => x; }

    int aliasLambda()
    {
        int r;
        call!(a => a + x)(r);
        return r;
    }
}

void call(alias f)(ref int r) @nogc { r = f(1); }

struct T(E)
{
    E e;
    E delegate() g()() @nogc { return () => e; }
}

void nestedStructInFunction() @nogc
{
    struct N
    {
        int v = 1;
        int m() @nogc { auto dg = () => v; return dg(); }
    }
    N n;
    assert(n.m() == 1);
}

// overwrites the stack region the callee frames used
int clobber(int depth) @nogc
{
    int[64] junk = -1;
    return depth ? clobber(depth - 1) + junk[depth & 63] : 0;
}

extern (C) void main()
{
    S s;
    assert(s.getX()() == 10);
    assert(s.addY()(1) == 21);
    assert(s.viaNamed()() == 200);
    assert(s.siblings()() == 30);
    assert(s.indifferent()() == 11);
    assert(s.nested()() == 31);
    assert(s.deep()() == 15);
    assert(s.threeDeep()() == 30);
    assert(s.threeDeepEscape()() == 30);
    assert(s.threeDeepLocals()() == 13);
    assert(s.mixed()() == 13);
    s.y = 20;
    assert(s.propagate() == 11);
    assert(s.reverse() == 11);
    assert(s.direct() == 20);
    assert(s.callsMember()() == 30);
    s.bump()();
    assert(s.x == 11);
    s.save();
    s.x = 1;
    assert(s.saved() == 21);
    assert(s.cget()() == 1);
    assert(s.aliasLambda() == 2);

    // the delegate's context is the object itself, and it sees later changes
    auto dg = s.getX();
    assert(dg.ptr is &s);
    s.x = 42;
    assert(dg() == 42);

    auto s2 = S(5);
    assert(s2.saved() == 5);
    s2.x = 6;
    assert(s2.saved() == 6);

    S s3;
    auto w = s3.wrapper(2);
    clobber(8);
    assert(w() == 12);
    assert(w.ptr is &s3);

    T!int t;
    t.e = 77;
    assert(t.g()() == 77);

    nestedStructInFunction();
}
