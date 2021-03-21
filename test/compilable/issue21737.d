struct Foo
{
    int opApply( int delegate(size_t, int) shared scope) shared
    {
        return 0;
    }
}

struct Foo1
{
    int opApply( int delegate(size_t, int) shared ) shared
    {
        return 0;
    }
}

struct Foo2
{
    int opApply( int delegate(size_t, int) shared @safe) shared
    {
        return 0;
    }
}
void test()
{
    shared Foo  foo;
    shared Foo1 foo1;
    shared Foo2 foo2;
    foreach(i, e; foo)  { }
    foreach(i, e; foo1) { }
    foreach(i, e; foo2) { }
    
}
