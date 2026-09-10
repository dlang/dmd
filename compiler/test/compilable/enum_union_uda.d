enum union Tag
{
    case Number(int),
    case Empty();
}

enum union BareTag
{
    case int,
    case bool;
}

@(Tag.Number(42))
struct NumberAnnotated {}

@(Tag.Empty)
struct EmptyAnnotated {}

@(BareTag(true))
struct BareAnnotated {}

enum numberAttribute = __traits(getAttributes, NumberAnnotated)[0];
enum emptyAttribute = __traits(getAttributes, EmptyAnnotated)[0];
enum bareAttribute = __traits(getAttributes, BareAnnotated)[0];

static assert(numberAttribute.__tag == 0);
static assert(emptyAttribute.__tag == 1);
static assert(bareAttribute.__tag == 1);

void main()
{
    assert(switch (numberAttribute)
    {
        case Number(value) => value == 42,
        case Empty() => false,
    });

    assert(switch (bareAttribute)
    {
        case int => false,
        case bool => true,
    });
}
