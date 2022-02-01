// https://issues.dlang.org/show_bug.cgi?id=22536

void foo(T)(scope T[]) {}
void foo(T)(scope T[], scope T[]) {}

int bar()
{
    int numDtor;

    struct S
    {
        int x;
        ~this() { ++numDtor; }
    }

    foo([S(1), S(2)]);
    return numDtor;
}

int bar2()
{

    int numDtor;

    struct S
    {
        int x;
        ~this() { ++numDtor; }
    }

    foo([S(1), S(2)], [S(3), S(4)]);
    return numDtor;
}

static assert(bar() == 2);
static assert(bar2() == 4);

// Test proper destruction at end of statement

struct Inc
{
    int* ptr;
    ~this()
    {
        (*ptr)++;
    }
}

int* boo(scope Inc[] arr)
{
    return arr[0].ptr;
}

int boo()
{
    int i;
    assert(*boo([ Inc(&i) ]) == 0);
    return 0;
}

static assert(boo() == 0);

// test that the runnable behavior matches CTFE
void main()
{
    assert(bar() == 2);
    assert(bar2() == 4);
    assert(boo() == 0);
}
