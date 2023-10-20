module link14834a;

struct DirIterator
{
    int i = 1;

    @property bool empty() { return i == 0; }
    @property int front() { return 10; }
    void popFront() { --i; }
}

auto dirEntries(string path)
{
    bool f(int x)
    {
        assert(path == ".");    // should pass
        return true;
    }
    return filter!f(DirIterator());
}

template filter(alias pred)
{
    auto filter(R)(R range)
    {
        return FilterResult!(pred, R)(range);
    }
}

struct FilterResult(alias pred, R)
{
    R input;

    this(R r)
    {
        input = r;
        while (!input.empty && !pred(input.front))
        {
            input.popFront();
        }
    }

    @property bool empty() { return input.empty; }

    @property auto ref front()
    {
        return input.front;
    }

    void popFront()
    {
        do
        {
            input.popFront();
        } while (!input.empty && !pred(input.front));
    }
}
