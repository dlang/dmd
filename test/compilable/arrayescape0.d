// REQUIRED_ARGS: -preview=dip1000

void test() @safe
{
    int[4] sarray = [1, 2, 3, 4];
    int[] slice = sarray[];
    int v = 5;
    slice ~= v;
}

class A {}
class B
{
    A[] a;
    void append(A e) @safe
    {
        a ~= e;
    }
}

void func(C myParam) @safe;

class C {}
class D
{
    void method0() @safe
    {
        foreach (ref e; Range.init)
            func(e);
    }

    C method1() @safe
    {
        foreach (ref e; Range.init)
            return e;
        return null;
    }
}

struct Range
{
    @safe:
    @property C front();
    void popFront();
    bool empty();
}
