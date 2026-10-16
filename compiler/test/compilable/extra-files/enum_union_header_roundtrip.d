module enum_union_header_roundtrip;

// 1. Tag access and basic variants
enum union Message
{
    case None();
    case Value(int value);
}

// 2. Case UDAs and static foreach in template function
struct Marker
{
    string name;
}

template AliasSeq(T...)
{
    alias AliasSeq = T;
}

enum union HardenedValue
{
    @Marker("none") case None();
    @Marker("some") case Some(int);
}

int inspect(T)(HardenedValue value)
{
    return switch (value)
    {
        static foreach (index; AliasSeq!(0, 1))
        {
            static if (index == 0)
                case None() => 0,
            else
                case Some(payload) => payload,
        }
    };
}

// 3. Tuple pattern matching in template function
struct Tuple(T...)
{
    T expand;
    alias expand this;
}

enum union TupleValue
{
    case Wrapped(Tuple!(int, int));
    case Record { Tuple!(int, int) point; };
}

int inspectTuple(T)(TupleValue value)
{
    return switch (value)
    {
        case Wrapped((left, right)) => left + right,
        case Record { point: (left, right) } => left + right,
    };
}
