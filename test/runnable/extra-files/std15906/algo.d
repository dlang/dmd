module std15906.algo;

template unaryFun(alias fun)
{
    alias unaryFun = fun;
}

template ElementType(R)
{
    static if (is(typeof(R.init.front) T))
        alias ElementType = T;
}

T front(T)(T[] )
{
    return [];
}

template map(fun...)
{
    auto map(Range)(Range r)
    {
        alias RE = ElementType!Range;
        alias _fun = unaryFun!fun;
        assert(!is(typeof(_fun(RE.init))));
        return MapResult!(_fun, Range)(r);
    }
}

struct MapResult(alias fun, R)
{
    R _input;

    @property front()
    {
        fun(_input.front);
    }
}

template filter(alias pred)
{
    auto filter(R)(R )
    {
        return FilterResult!(pred, R)();
    }
}

struct FilterResult(alias pred, R)
{
    R _input;

    @property front()
    {
        return _input;
    }
}
