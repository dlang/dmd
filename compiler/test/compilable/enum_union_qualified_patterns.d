module enum_union_qualified_patterns;

class C1 {}
class C2 : C1 {}

enum union Value
{
    case C1,
    case C3 = C2,
    case Unit(),
    case Tuple(int),
}

string classify(Value value)
{
    return switch (value)
    {
        case C1 => "C1",
        case Value.C3 => "C2",
        case Value.Unit => "unit",
        case Value.Tuple => "tuple",
    };
}

string classifyByType(Value value)
{
    return switch (value)
    {
        case C1 => "C1",
        case enum_union_qualified_patterns.C2 => "C2",
        case Value.Unit => "unit",
        case Value.Tuple => "tuple",
    };
}

string classifyExplicitUnit(Value value)
{
    return switch (value)
    {
        case Value.Unit() => "unit",
        case Value.Tuple => "tuple",
        case C1 => "C1",
        case C2 => "C2",
    };
}

void main()
{
    assert(classify(Value(new C1)) == "C1");
    assert(classify(Value(new C2)) == "C2");
    assert(classify(Value.Unit) == "unit");
    assert(classify(Value.Tuple(1)) == "tuple");
    assert(classifyByType(Value(new C2)) == "C2");
    assert(classifyExplicitUnit(Value.Unit()) == "unit");
}