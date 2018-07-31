module linkdebug_range;

import linkdebug_primitives : popBackN, moveAt;

auto stride(R)(R r)
{
    static struct Result
    {
        R source;

        void popBack()
        {
            popBackN(source, 0);
        }

        uint moveAt(size_t n)
        {
            return .moveAt(source, n);
        }
    }
    return Result(r);
}

struct SortedRange(Range, alias pred = "a < b")
{
    this(Range input)
    out
    {
        dbgVerifySorted();
    }
    body
    {
    }

    void dbgVerifySorted()
    {
        debug
        {
            uint[] _input;
            auto st = stride(_input);
        }
    }
}

auto assumeSorted(alias pred = "a < b", R)(R r)
{
    return SortedRange!(R, pred)(r);
}
