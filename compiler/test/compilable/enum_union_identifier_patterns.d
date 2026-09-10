class C1 {}
class C2 : C1 {}
struct S {}

enum union Bare
{
    case C1,
    case C2,
    case S,
}

enum union Named
{
    case Unit(),
    case Tuple(int),
}

string classifyBare(Bare value)
{
    return switch (value)
    {
        case C1 => "C1",
        case C2 => "C2",
        case S => "S",
    };
}

string classifyNamed(Named value)
{
    return switch (value)
    {
        case Unit => "unit",
        case Tuple => "tuple",
    };
}

string classifyUnitCall(Named value)
{
    return switch (value)
    {
        case Unit() => "unit",
        case Tuple => "tuple",
    };
}

void main()
{
    assert(classifyBare(Bare(new C2)) == "C2");
    assert(classifyBare(Bare(S())) == "S");
    assert(classifyNamed(Named.Unit) == "unit");
    assert(classifyNamed(Named.Tuple(1)) == "tuple");
    assert(classifyUnitCall(Named.Unit()) == "unit");
}