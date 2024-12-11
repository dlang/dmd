/*
TEST_OUTPUT:
---
fail_compilation/diag13884.d(20): Error: functions cannot return a sequence (use `std.typecons.Tuple`)
    [Foo(1)].map!(t => t.tupleof);
                  ^
fail_compilation/diag13884.d(27):        instantiated from here: `MapResult!((t) => t.tupleof, Foo[])`
        return MapResult!(fun, Range)(r);
               ^
fail_compilation/diag13884.d(20):        instantiated from here: `map!(Foo[])`
    [Foo(1)].map!(t => t.tupleof);
            ^
---
*/

struct Foo { int x; }

void main()
{
    [Foo(1)].map!(t => t.tupleof);
}

template map(fun...)
{
    auto map(Range)(Range r)
    {
        return MapResult!(fun, Range)(r);
    }
}

struct MapResult(alias fun, R)
{
    R _input;

    @property auto ref front()
    {
        return fun(_input[0]);
    }

}
