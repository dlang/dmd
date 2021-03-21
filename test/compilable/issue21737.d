/*
REQUIRED_ARGS: -preview=nosharedaccess
 */
import core.atomic;
struct S
{
    int result;
    void inc(int i) shared @safe {
        result.atomicOp!"+="(i);
    }
}

struct Foo
{
    int opApply( int delegate(size_t, int) shared scope dg) shared
    {
        dg(0,42);
        return 0;
    }
}

struct Foo1
{
    int opApply( int delegate(size_t, int) shared dg) shared
    {
        dg(0,42);
        return 0;
    }
}

struct Foo2
{
    int opApply( int delegate(size_t, int) shared @safe dg) shared
    {
        dg(0,42);
        return 0;
    }
}
int test()
{
    shared Foo  foo;
    shared Foo1 foo1;
    shared Foo2 foo2;
    shared S s;
    
    foreach(i, e; foo)  {
        s.inc(1);
    }
    foreach(i, e; foo1) {
        s.inc(2);
    }
    foreach(i, e; foo2) {
        s.inc(3);
    }
    
    static assert(!__traits(compiles, {
        S ss;
        foreach(i, e; foo)  { ss.inc(1); }
        foreach(i, e; foo1) { ss.inc(2); }
        foreach(i, e; foo2) { ss.inc(3); }
    }));
    return s.result;
}
