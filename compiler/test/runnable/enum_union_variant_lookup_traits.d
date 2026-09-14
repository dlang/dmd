module enum_union_variant_lookup_traits;

enum union Source
{
    case None(),
    case Point(double x, double y),
    case User { int id; string name; },
    case Slice = const(ubyte)[],
    case int;

    static void helper() {}
}

void main()
{
    alias Variants = __traits(allVariants, Source);

    static assert(__traits(hasVariant, Source, "None"));
    static assert(__traits(hasVariant, Source, "Point"));
    static assert(__traits(hasVariant, Source, "User"));
    static assert(__traits(hasVariant, Source, "Slice"));
    static assert(__traits(hasVariant, Source, int));
    static assert(!__traits(hasVariant, Source, "missing"));
    static assert(!__traits(hasVariant, Source, "helper"));
    static assert(!__traits(hasVariant, Source, double));

    static assert(__traits(isSame, __traits(getVariant, Source, "None"), Variants[0]));
    static assert(__traits(isSame, __traits(getVariant, Source, "Point"), Variants[1]));
    static assert(__traits(isSame, __traits(getVariant, Source, "User"), Variants[2]));
    static assert(__traits(isSame, __traits(getVariant, Source, "Slice"), Variants[3]));
    static assert(is(__traits(getVariant, Source, int) == Variants[4]));
}