module enum_union_conversion_ranking;

enum union ConfigValue
{
    case bool,
    case long,
    case double,
    case string,
    case string[],
}

struct Empty
{
}

enum union WithUnitVariant
{
    case None(),
    case int,
}

void main()
{
    WithUnitVariant unit = WithUnitVariant.None;
    assert(unit.__tag == 0);
    static assert(!__traits(compiles, (() {
        WithUnitVariant unrelated = Empty();
    })()));

    ConfigValue literalBool = false;
    assert(literalBool.__tag == 0);

    ConfigValue castBool = cast(bool) false;
    assert(castBool.__tag == 0);

    ConfigValue constructedBool = bool(false);
    assert(constructedBool.__tag == 0);

    bool boolValue;
    ConfigValue typedBool = boolValue;
    assert(typedBool.__tag == 0);

    ConfigValue longValue = long(42);
    assert(longValue.__tag == 1);

    ConfigValue doubleValue = 42.0;
    assert(doubleValue.__tag == 2);

    ConfigValue stringValue = "value";
    assert(stringValue.__tag == 3);

    ConfigValue stringsValue = ["first", "second"];
    assert(stringsValue.__tag == 4);
}