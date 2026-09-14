module enum_union_variant_spec;

template AliasSeq(T...) { alias AliasSeq = T; }

enum union Source
{
    case None(),
    case Point(double x, double y),
    case Move(double, double),
    case Arc(double, double, double radius),
    case User { int id; string name; },
    case Slice = const(ubyte)[],
    case int,
}

void testReflection()
{
    alias Variants = __traits(allVariants, Source);

    static assert(__traits(variantKind, Variants[0]) == "unit");
    static assert(__traits(variantKind, Variants[1]) == "tuple");
    static assert(__traits(variantKind, Variants[2]) == "tuple");
    static assert(__traits(variantKind, Variants[3]) == "tuple");
    static assert(__traits(variantKind, Variants[4]) == "struct");
    static assert(__traits(variantKind, Variants[5]) == "alias");
    static assert(__traits(variantKind, Variants[6]) == "bare");

    static foreach (Variant; Variants)
        static assert(__traits(variantParams, Variant).length ==
            __traits(variantParamNames, Variant).length);

    static assert(is(__traits(variantParams, Variants[1]) == AliasSeq!(double, double)));
    static assert(__traits(variantParamNames, Variants[1]) == AliasSeq!("x", "y"));
    static assert(is(__traits(variantParams, Variants[2]) == AliasSeq!(double, double)));
    static assert(__traits(variantParamNames, Variants[2]) == AliasSeq!("", ""));
    static assert(is(__traits(variantParams, Variants[3]) == AliasSeq!(double, double, double)));
    static assert(__traits(variantParamNames, Variants[3]) == AliasSeq!("", "", "radius"));
    static assert(is(__traits(variantParams, Variants[4]) == AliasSeq!(int, string)));
    static assert(__traits(variantParamNames, Variants[4]) == AliasSeq!("id", "name"));

    static assert(__traits(hasVariant, Source, "Point"));
    static assert(__traits(hasVariant, Source, "User"));
    static assert(__traits(hasVariant, Source, int));
    static assert(!__traits(hasVariant, Source, "NonExistent"));
    static assert(!__traits(hasVariant, Source, double));
}

enum union Target
{
    case __traits(variantDeclarationOf, __traits(getVariant, Source, "None"));
    case __traits(variantDeclarationOf, __traits(getVariant, Source, "Point"), "");
    case __traits(variantDeclarationOf, __traits(getVariant, Source, int));
    case __traits(variantDeclarationOf, __traits(getVariant, Source, "Slice"));
    case __traits(variantDeclarationOf, __traits(getVariant, Source, "Move"), "RelativeMove");
    case __traits(variantDeclarationOf, __traits(getVariant, Source, "User"), "Account");
    case __traits(variantDeclarationOf, __traits(getVariant, Source, int), "Code");
}

void testSplicing()
{
    Target t1 = Target.None();
    Target t2 = Target.Point(1.0, 2.0);
    Target t3 = 404;
    Target t4 = Target.Slice([ubyte(1), 2, 3]);
    Target t5 = Target.RelativeMove(5.0, 10.0);
    Target t6 = Target.Account(1, "Alice");
    Target t7 = Target.Code(500);

    static assert(is(Target.Account == struct));
    static assert(__traits(hasVariant, Target, int));
    static assert(__traits(hasVariant, Target, "Code"));
    assert(t1.__tag != t2.__tag);
    assert(t3.__tag != t4.__tag);
    assert(t5.__tag != t6.__tag);
    assert(t7.__tag == __traits(getTag, Target, __traits(getVariant, Target, "Code")));
}

void main()
{
    testReflection();
    testSplicing();
}