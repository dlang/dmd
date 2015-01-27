/*
TEST_OUTPUT:
---
fail_compilation/ice12554.d(18): Error: pure function 'ice12554.main.__lambda1' cannot call impure function 'ice12554.array!(MapResult!((y) => x)).array'
fail_compilation/ice12554.d(37):        instantiated from here: MapResult!((x) => foo.map!(MapResultS, (y) => x).array)
fail_compilation/ice12554.d(18):        instantiated from here: map!(int[])
fail_compilation/ice12554.d(21): Error: pure function 'ice12554.main.__lambda2' cannot call impure function 'ice12554.array!(MapResult!((y) => x)).array'
fail_compilation/ice12554.d(37):        instantiated from here: MapResult!((x) => foo.map!(MapResultC, (y) => x).array)
fail_compilation/ice12554.d(21):        instantiated from here: map!(int[])
---
*/

void main() pure
{
    int[] foo;

    // if indirectly instantiated aggregate is struct (== MapResultS)
    foo.map!(MapResultS, x => foo.map!(MapResultS, y => x).array);

    // if indirectly instantiated aggregate is class (== MapResultC)
    foo.map!(MapResultC, x => foo.map!(MapResultC, y => x).array);
}

T array(T)(T a)
{
    static int g; g = 1;    // impure operation
    return a;
}

template map(alias MapResult, fun...)
{
    auto map(Range)(Range r)
    {
        alias AppliedReturnType(alias f) = typeof(f(r[0]));
        static assert(!is(AppliedReturnType!fun == void));

        return MapResult!(fun).init;
    }
}

struct MapResultS(alias fun)
{
    @property front()
    {
        return fun(1);
    }
}

class MapResultC(alias fun)
{
    @property front()
    {
        return fun(1);
    }
}
