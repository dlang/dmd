/*
TEST_OUTPUT:
---
fail_compilation/ice12174.d(18): Error: no property `sum` for `[1, 2, 3]` of type `int[]`
    enum foo3 = (int n) => [1,2,3].sum;
                                  ^
fail_compilation/ice12174.d(26): Error: CTFE failed because of previous errors in `this`
        return FilterResult!(pred, Range)(rs);
                                         ^
fail_compilation/ice12174.d(19):        called from here: `filter([1, 2, 3])`
    enum bar3 = [1,2,3].filter!(n => n % foo3(n) == 0);
                       ^
---
*/

void main()
{
    enum foo3 = (int n) => [1,2,3].sum;
    enum bar3 = [1,2,3].filter!(n => n % foo3(n) == 0);
}

template filter(alias pred)
{
    auto filter(Range)(Range rs)
    {
        return FilterResult!(pred, Range)(rs);
    }
}

private struct FilterResult(alias pred, R)
{
    R _input;

    this(R r)
    {
        _input = r;
        while (_input.length && !pred(_input[0]))
        {
            _input = _input[1..$];
        }
    }

    @property bool empty() { return _input.length == 0; }

    @property auto ref front()
    {
        return _input[0];
    }

    void popFront()
    {
        do
        {
            _input = _input[1..$];
        } while (_input.length && !pred(_input[0]));
    }
}
