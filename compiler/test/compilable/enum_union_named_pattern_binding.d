enum union Value
{
    case Unit(),
    case Pair(int left, int right),
    case Record { int value; }
}

enum union Units
{
    case First(),
    case Second(),
}

auto unitPayload(Units value)
{
    return switch (value)
    {
        case First payload => payload,
        case Second payload => payload,
    };
}

static assert(unitPayload(Units.First).sizeof == 1);

int main()
{
    return switch (Value.Unit)
    {
        case Unit value => cast(int) value.sizeof,
        case Pair value => value.left + value.right,
        case Record value => value.value,
    };
}