module enum_union_tuple_pattern_header;

struct Tuple(T...)
{
    T expand;
    alias expand this;
}

enum union Value
{
    case Wrapped(Tuple!(int, int));
    case Record { Tuple!(int, int) point; };
}

int inspect(T)(Value value)
{
    return switch (value)
    {
        case Wrapped((left, right)) => left + right,
        case Record { point: (left, right) } => left + right,
    };
}