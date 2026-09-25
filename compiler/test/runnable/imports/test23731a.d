module imports.test23731a;

struct Wrapper(T)
{
    T[] values;
}

auto gen()()
{
    auto a = [Wrapper!int()];
    return a.length;
}

enum config = gen();
