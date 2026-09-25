struct Tuple(T...)
{
    T expand;
    alias expand this;
}

auto tuple(T...)(T values)
{
    return Tuple!T(values);
}

enum union Value
{
    case Wrapped(Tuple!(int, string));
    case Record { Tuple!(int, int) point; int label; };
    case Nested(Tuple!(int, Tuple!(int, int)));
}

int conditionEvaluations;

Value nextValue()
{
    conditionEvaluations++;
    return Value.Wrapped(tuple(8, "answer"));
}

int inspectNext()
{
    return switch (nextValue())
    {
        case Wrapped((number, text)) => number,
        default => 0,
    };
}

int inspect(Value value)
{
    return switch (value)
    {
        case Wrapped((number, text)) if (text == "answer") => number,
        case Record { point: (x, y), label } => x + y + label,
        case Nested((head, (left, right))) => head + left + right,
        default => 0,
    };
}

void main()
{
    assert(inspect(Value.Wrapped(tuple(42, "answer"))) == 42);
    assert(inspect(Value.Record(tuple(1, 2), 3)) == 6);
    assert(inspect(Value.Nested(tuple(1, tuple(2, 3)))) == 6);
    assert(inspectNext() == 8);
    assert(conditionEvaluations == 1);

    const Value qualified = Value.Wrapped(tuple(7, "answer"));
    auto result = switch (qualified)
    {
        case Wrapped((number, text)) =>
            is(typeof(number) == const int) && is(typeof(text) == const string)
                ? number : 0,
        default => 0,
    };
    assert(result == 7);
}
