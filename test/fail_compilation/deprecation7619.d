// REQUIRED_ARGS: -de
// https://issues.dlang.org/show_bug.cgi?id=6519

T foo(T)(T t = T.init)
{
    return T.init;
}

struct Struct(T)
{
    T m;

    void foo()
    {
        T t;
    }
}

alias Alias(T) = T;

enum TypeSize(T) = T.sizeof;

template Multi(T)
{
    void bar(T t = T.init)
    {
        T var;
    }
}

mixin template MultiMixin(T)
{
    T bar(T t = T.init)
    {
        T var;
        return var;
    }
}

deprecated struct S {}

deprecated int old() { return 0; }

int normal() { return 1; }

/*
Most importantly, no deprecation messages when instantiated from a deprecated scope
*/
#line 100
deprecated void deprecatedMain()
{
    { foo!(S)(); }
    { Struct!(S) s; }
    { alias A = Alias!(S); }
    { enum ts = TypeSize!(S); }
    {
        alias M1 = Multi!(S);
        M1.bar();
    }
    {
        mixin MultiMixin!(S);
        bar();
    }
}

/*
Only issue deprecations for the deprecated parameters and instances

TEST_OUTPUT:
---
fail_compilation/deprecation7619.d(202): Deprecation: struct `deprecation7619.S` is deprecated
fail_compilation/deprecation7619.d(203): Deprecation: struct `deprecation7619.S` is deprecated
fail_compilation/deprecation7619.d(204): Deprecation: struct `deprecation7619.S` is deprecated
fail_compilation/deprecation7619.d(205): Deprecation: struct `deprecation7619.S` is deprecated
fail_compilation/deprecation7619.d(207): Deprecation: struct `deprecation7619.S` is deprecated
---
*/
#line 200
void normalMain1()
{
    { foo!(S)(); }
    { Struct!(S) s; }
    { alias A = Alias!(S); }
    { enum ts = TypeSize!(S); }
    {
        alias M1 = Multi!(S);
        M1.bar();
    }
}

/*
Works for template mixins as well

TEST_OUTPUT:
---
fail_compilation/deprecation7619.d(302): Deprecation: struct `deprecation7619.S` is deprecated
fail_compilation/deprecation7619.d(302): Error: mixin `deprecation7619.normalMain2.MultiMixin!(S)` error instantiating
---
*/
#line 300
void normalMain2()
{
    mixin MultiMixin!(S);
    bar();
}

/*
Inference works even if the symbols isn't a template parameter

TEST_OUTPUT:
---
fail_compilation/deprecation7619.d(422): Deprecation: template instance `deprecation7619.templMain1!()` is deprecated
fail_compilation/deprecation7619.d(423): Deprecation: template instance `deprecation7619.templMain2!()` is deprecated
fail_compilation/deprecation7619.d(424): Deprecation: template instance `deprecation7619.templMain3!()` is deprecated
---
*/
#line 400
void templMain1()()
{
    { foo!(S)(); }
    { Struct!(S) s; }
    { alias A = Alias!(S); }
    { enum ts = TypeSize!(S); }
}

void templMain2()()
{
    alias M1 = Multi!(S);
    M1.bar();
}

void templMain3()()
{
    mixin MultiMixin!(S);
    bar();
}

void forceCompile()
{
    templMain1();
    templMain2();
    templMain3();
}

/*
Inference resolves the correct overload.

TODO: Deprecations for oveerloads depend on the declaration order, hence the wrong diagnostics for overload* below.
      (This happens while preparing the template instance and is already in master, hence ignoring it for now)

TEST_OUTPUT:
---
fail_compilation/deprecation7619.d(503): Deprecation: template instance `deprecation7619.call!(overload1)` is deprecated
fail_compilation/deprecation7619.d(504): Deprecation: function `deprecation7619.overload2` is deprecated
fail_compilation/deprecation7619.d(505): Deprecation: function `deprecation7619.overload2` is deprecated
fail_compilation/deprecation7619.d(505): Deprecation: template instance `deprecation7619.call!(overload2)` is deprecated
---
*/
#line 500
void other()
{
    call!overload1(1);
    call!overload1();
    call!overload2(true);
    call!overload2();
}

void overload1(int) {}

deprecated void overload1() {}

deprecated void overload2() {}

void overload2(bool) {}

auto call(alias f, T...)(T params)
{
    return f(params);
}

/*
Inference works across transitive template instances.

TEST_OUTPUT:
---
fail_compilation\deprecation7619.d(602): Deprecation: struct `deprecation7619.S` is deprecated
fail_compilation\deprecation7619.d(602): Deprecation: template instance `deprecation7619.chain1!(const(S))` is deprecated
---
*/
#line 600
void caller()
{
    chain1!(const S)();
}

deprecated void deprCaller()
{
    chain1!(immutable S)();
}

void chain1(T)()
{
    T t;
    chain2(t);
}

void chain2(T)(T par)
{
    static if (is(T == const U, U))
        chain1!U();
    else
        T var;
}
