module enum_union_patterns;

class C1 {}
class C2 : C1 {}
struct S {}

enum union Bare
{
    case C1;
    case C2;
    case S;
}

enum union Named
{
    case Unit();
    case Tuple(int);
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

// Qualified patterns
enum union QualValue
{
    case C1;
    case C3 = C2;
    case Unit();
    case Tuple(int);
}

string classifyQual(QualValue value)
{
    return switch (value)
    {
        case C1 => "C1",
        case QualValue.C3 => "C2",
        case QualValue.Unit => "unit",
        case QualValue.Tuple => "tuple",
    };
}

string classifyByType(QualValue value)
{
    return switch (value)
    {
        case C1 => "C1",
        case enum_union_patterns.C2 => "C2",
        case QualValue.Unit => "unit",
        case QualValue.Tuple => "tuple",
    };
}

string classifyExplicitUnit(QualValue value)
{
    return switch (value)
    {
        case QualValue.Unit() => "unit",
        case QualValue.Tuple => "tuple",
        case C1 => "C1",
        case C2 => "C2",
    };
}

bool classifyQualifiedBinding(QualValue value)
{
    return switch (value)
    {
        case enum_union_patterns.C2 instance => instance !is null,
        default => false,
    };
}

// Named pattern bindings
enum union BoundValue
{
    case Unit();
    case Pair(int left, int right);
    case Record { int value; };
}

enum union Units
{
    case First();
    case Second();
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

enum left = 100;

int pairLeft(BoundValue value)
{
    return switch (value)
    {
        case Pair(left, right) => left,
        default => 0,
    };
}

static assert(pairLeft(BoundValue.Pair(1, 2)) == 1);

void main()
{
    assert(classifyBare(Bare(new C2)) == "C2");
    assert(classifyBare(Bare(S())) == "S");
    assert(classifyNamed(Named.Unit) == "unit");
    assert(classifyNamed(Named.Tuple(1)) == "tuple");
    assert(classifyUnitCall(Named.Unit()) == "unit");

    assert(classifyQual(QualValue(new C1)) == "C1");
    assert(classifyQual(QualValue(new C2)) == "C2");
    assert(classifyQual(QualValue.Unit) == "unit");
    assert(classifyQual(QualValue.Tuple(1)) == "tuple");
    assert(classifyByType(QualValue(new C2)) == "C2");
    assert(classifyExplicitUnit(QualValue.Unit()) == "unit");
    assert(classifyQualifiedBinding(QualValue(new C2)));

    assert(switch (BoundValue.Unit)
    {
        case Unit value => cast(int) value.sizeof,
        case Pair value => value.left + value.right,
        case Record value => value.value,
    } == 1);
}
