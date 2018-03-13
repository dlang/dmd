/*
REQUIRED_ARGS: -dip1000
PERMUTE_ARGS:
*/

/*
TEST_OUTPUT:
---
fail_compilation/retscope3.d(2008): Error: returning `& i` escapes a reference to local variable `i`
fail_compilation/retscope3.d(2017): Error: returning `S2000(& i)` escapes a reference to local variable `i`
---
*/

#line 2000

// https://issues.dlang.org/show_bug.cgi?id=17790

@safe:

int* bar1()
{
    int i;
    int*[] arr = [ &i ];
    return arr[0];
}

struct S2000 { int* p; }

S2000 bar2()
{
    int i;
    S2000[] arr = [ S2000(&i) ];
    return arr[0];
}

void bar3(string[] u...) @safe pure nothrow @nogc
{
    foreach (str; u)
    {
    }
}

void bar4()
{
    static struct S { int* p; }
    S[2][10] pairs;
    foreach (ref pair; pairs)
    {
    }
}

/**********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope3.d(3027): Error: scope variable `l` assigned to `elem` with longer lifetime
---
*/

#line 3000

struct List
{
    Elem front() @safe return scope;

    ~this() @trusted scope;

    @disable this(this);

    void* data;
}

struct Elem
{
    void* data;
}

List list() @trusted
{
    return List();
}

void test3000() @safe
{
    Elem elem;
    {
        auto l = list(); // inferred as scope
        elem = l.front; // escapes, b/c l isn't scoped
    }
}

