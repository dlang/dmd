module enum_union_attributes;

enum Marker;

deprecated enum union DeprecatedValue
{
    case None(),
}

deprecated("use ReplacementValue") enum union DeprecatedMessageValue
{
    case None(),
}

align(16) enum union AlignedValue
{
    case long,
}

extern(C) enum union CValue
{
    case int,
}

extern(C++) enum union CppValue
{
    case int,
}

export enum union ExportedValue
{
    case int,
}

package enum union PackageValue
{
    case int,
}

@Marker enum union AnnotatedValue
{
    case int,
}

struct Container
{
    private align(8) enum union NestedValue
    {
        case int,
    }

    static assert(__traits(getProtection, NestedValue) == "private");
    static assert(NestedValue.alignof == 8);
}

static assert(__traits(isDeprecated, DeprecatedValue));
static assert(__traits(isDeprecated, DeprecatedMessageValue));
static assert(AlignedValue.alignof == 16);
static assert(__traits(getLinkage, CValue) == "C");
static assert(__traits(getLinkage, CppValue) == "C++");
static assert(__traits(getProtection, ExportedValue) == "export");
static assert(__traits(getProtection, PackageValue) == "package");
static assert(__traits(getAttributes, AnnotatedValue).length == 1);

void acceptAttributes()
{
    deprecated enum union LocalDeprecatedValue
    {
        case None(),
    }

    align(8) enum union LocalAlignedValue
    {
        case int,
    }

    static assert(__traits(isDeprecated, LocalDeprecatedValue));
    static assert(LocalAlignedValue.alignof == 8);

    AlignedValue alignedValue = long(1);
    CValue cValue = int(2);
    ExportedValue exportedValue = int(3);
    PackageValue packageValue = int(4);
}