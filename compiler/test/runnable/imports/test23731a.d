module imports.test23731a;

struct Wrapper(T)
{
    T[] values;
}

enum wrapperIntSize = Wrapper!int.sizeof;
