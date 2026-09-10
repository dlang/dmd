struct ExternalStruct
{
    int id;
}

struct Wrapper(T)
{
    T value;
}

enum union Result(T)
{
    case Success(T),
    case Failure(),
    case ExternalStruct,
    case Wrapper!int,
    case string,
}

enum union NamedUnit
{
    case ExternalStruct(),
}

enum union VariantPack(Types...)
{
    case Empty(),
    static foreach (T; Types)
        case T;
}

alias MyResult = Result!int;
alias MyPack = VariantPack!(ExternalStruct, int);

int resultValue(MyResult result)
{
    return switch (result)
    {
        case Success(value) => value,
        case Failure() => -1,
        case ExternalStruct value => value.id,
        case Wrapper!int value => value.value,
        case string value => cast(int) value.length,
    };
}

int packValue(MyPack value)
{
    return switch (value)
    {
        case Empty() => 0,
        case ExternalStruct value => value.id,
        case int value => value,
    };
}

int namedUnitBare(NamedUnit value)
{
    return switch (value)
    {
        case ExternalStruct => 1,
    };
}

int namedUnitCall(NamedUnit value)
{
    return switch (value)
    {
        case ExternalStruct() => 2,
    };
}

void main()
{
    assert(resultValue(MyResult.Success(1)) == 1);
    assert(resultValue(MyResult.Failure()) == -1);
    assert(resultValue(ExternalStruct(10)) == 10);
    assert(resultValue(Wrapper!int(20)) == 20);
    assert(resultValue("hello") == 5);
    assert(NamedUnit.ExternalStruct().__tag == 0);
    assert(namedUnitBare(NamedUnit.ExternalStruct) == 1);
    assert(namedUnitCall(NamedUnit.ExternalStruct()) == 2);

    assert(packValue(MyPack.Empty()) == 0);
    assert(packValue(ExternalStruct(20)) == 20);
    assert(packValue(30) == 30);
}