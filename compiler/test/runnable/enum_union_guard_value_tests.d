enum Color
{
    red,
    blue,
}

class Reference
{
}

struct Comparable
{
    int value;

    bool opEquals(const Comparable other) const
    {
        return value == other.value;
    }
}

enum union Value
{
    case Number(int);
    case Text(string);
    case ColorValue(Color);
    case ArrayValue(int[]);
    case ReferenceValue(Reference);
    case ComparableValue(Comparable);
}

bool matches(Value value, Reference expectedReference)
{
    return switch (value)
    {
        case Number(number) if (number == 42) => true,
        case Text(text) if (text == "answer") => true,
        case ColorValue(color) if (color == Color.blue) => true,
        case ArrayValue(items) if (items == [1, 2, 3]) => true,
        case ReferenceValue(reference) if (reference is expectedReference) => true,
        case ComparableValue(item) if (item == Comparable(42)) => true,
        default => false,
    };
}

void main()
{
    auto reference = new Reference();
    assert(matches(Value.Number(42), reference));
    assert(matches(Value.Text("answer"), reference));
    assert(matches(Value.ColorValue(Color.blue), reference));
    assert(matches(Value.ArrayValue([1, 2, 3]), reference));
    assert(matches(Value.ReferenceValue(reference), reference));
    assert(matches(Value.ComparableValue(Comparable(42)), reference));
    assert(!matches(Value.Number(7), reference));
}