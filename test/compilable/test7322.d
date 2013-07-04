// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
compilable/test7322.d(29): Deprecation: function test7322.S7322.baz7322 is deprecated
compilable/test7322.d(42): Deprecation: function test7322.foo7322 is deprecated
compilable/test7322.d(49): Deprecation: function test7322.S7322.bar7322 is deprecated
compilable/test7322.d(53): Deprecation: function test7322.S7322.baz7322 is deprecated
---
*/

deprecated
int foo7322(real a) { return 1; }
int foo7322(long a) { return 0; }

struct S7322
{
    deprecated
    int bar7322(real a) { return 1; }
    int bar7322(long a) { return 0; }

    deprecated
    int baz7322(real a)           { return 1; }
    int baz7322(long a) immutable { return 0; }

    // DelegateExp::semantic(!func->isNested() && hasOverloads)
    void test1()
    {
        auto dg = &baz7322;                 // deprecated!
        static assert(is(typeof(dg) == int delegate(real)));
    }
    void test2() immutable
    {
        auto dg = &baz7322;
        static assert(is(typeof(dg) == int delegate(long) immutable));
    }
}

void test7322a()
{
    // SymOffExp::implicitCastTo()
    int function(real) fp1 = &foo7322;      // deprecated!
    int function(long) fp2 = &foo7322;

    S7322 sm;
    immutable S7322 si;

    // DelegateExp::implicitCastTo()
    int delegate(real) dg1 = &sm.bar7322;   // deprecated!
    int delegate(long) dg2 = &sm.bar7322;

    // DotVarExp::semantic(var->isFuncDeclaration() && hasOverloads)
    auto dg3 = &sm.baz7322;                 // deprecated!
    static assert(is(typeof(dg3) == int delegate(real)));

    auto dg4 = &si.baz7322;
    static assert(is(typeof(dg4) == int delegate(long) immutable));
}

deprecated void test7322b()
{
    // SymOffExp::implicitCastTo()
    int function(real) fp1 = &foo7322;      // deprecated!
    int function(long) fp2 = &foo7322;

    S7322 sm;
    immutable S7322 si;

    // DelegateExp::implicitCastTo()
    int delegate(real) dg1 = &sm.bar7322;   // deprecated!
    int delegate(long) dg2 = &sm.bar7322;

    // DotVarExp::semantic(var->isFuncDeclaration() && hasOverloads)
    auto dg3 = &sm.baz7322;                 // deprecated!
    static assert(is(typeof(dg3) == int delegate(real)));

    auto dg4 = &si.baz7322;
    static assert(is(typeof(dg4) == int delegate(long) immutable));
}
