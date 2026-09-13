enum union Value
{
    case First(int),
    case Second(int),
}

enum value = Value.Second(42);
enum result = switch (value)
{
    case First(...) => 0,
    case Second(42) => 42,
    case Second(...) => 0,
};

static assert(result == 42);