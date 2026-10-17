/*
TEST_OUTPUT:
---
fail_compilation/closure_this.d(16): Error: function `closure_this.S.both` is `@nogc` yet allocates closure for `both()` with the GC
fail_compilation/closure_this.d(16):        delegate `() => this.x + local` closes over variable `this`
fail_compilation/closure_this.d(19): Error: function `closure_this.S.two` is `@nogc` yet allocates closure for `two()` with the GC
fail_compilation/closure_this.d(22):        delegate `() => local` closes over variable `local`
fail_compilation/closure_this.d(19):        `local` declared here
fail_compilation/closure_this.d(38): Error: function `closure_this.C.fd` is `@nogc` yet allocates closure for `fd()` with the GC
fail_compilation/closure_this.d(46):        delegate `() => this.x` closes over variable `this`
---
*/
struct S
{
    int x;
    int delegate() both(int local) @nogc { return () => x + local; }

    // the this-only lambda is fine, the other one still needs a closure
    void two(int local) @nogc
    {
        int delegate() a = () => x;
        int delegate() b = () => local;
    }

    // no closure: only `this` is captured
    int delegate() ok() @nogc { return () => x; }
}

/* A local struct's template member function is only analyzed when it is
 * instantiated, which may be after the method's own analysis, and a
 * delegate with `this` as its context could have constructed the struct.
 * So no nested function of a method with a local struct gets `this` as its
 * context, and this needs a closure as before.
 */
class C
{
    int x = 42;
    auto fd() @nogc
    {
        int y = 7;
        struct L
        {
            int get()() { return y; }
            int dummy;
        }
        int delegate() @nogc dg = () => x;
        static struct R(T) { int delegate() @nogc dg; T s; }
        return R!L(dg, L());
    }
}
