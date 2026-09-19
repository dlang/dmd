struct UDA {}

enum union Named
{
    @UDA case Number(int),
    case Empty();
}

static assert(__traits(getAttributes, Named.Number).length == 1);

enum union Bare
{
    @UDA case int,
    case bool;
}

void main()
{
    Bare number = 1;
    assert(number.__tag == 0);
}
