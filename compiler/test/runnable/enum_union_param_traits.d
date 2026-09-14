module enum_union_param_traits;

template AliasSeq(T...) { alias AliasSeq = T; }

enum union Shape
{
    case None(),
    case MoveTo(double, double),
    case Circle(double x, double y, double radius),
    case Arc(double, double, double radius),
    case User { int id; string name; },
    case int,
    case Slice = ubyte[],
}

void main()
{
    alias Variants = __traits(allVariants, Shape);

    static assert(__traits(variantParams, Variants[0]).length == 0);
    static assert(__traits(variantParamNames, Variants[0]).length == 0);

    static assert(is(__traits(variantParams, Variants[1]) == AliasSeq!(double, double)));
    static assert(__traits(variantParamNames, Variants[1]) == AliasSeq!("", ""));

    static assert(is(__traits(variantParams, Variants[2]) == AliasSeq!(double, double, double)));
    static assert(__traits(variantParamNames, Variants[2]) == AliasSeq!("x", "y", "radius"));

    static assert(is(__traits(variantParams, Variants[3]) == AliasSeq!(double, double, double)));
    static assert(__traits(variantParamNames, Variants[3]) == AliasSeq!("", "", "radius"));

    static assert(is(__traits(variantParams, Variants[4]) == AliasSeq!(int, string)));
    static assert(__traits(variantParamNames, Variants[4]) == AliasSeq!("id", "name"));

    static assert(__traits(variantParams, Variants[5]).length == 0);
    static assert(__traits(variantParamNames, Variants[5]).length == 0);

    static assert(__traits(variantParams, Variants[6]).length == 0);
    static assert(__traits(variantParamNames, Variants[6]).length == 0);

    static foreach (Variant; Variants)
    {
        static assert(__traits(variantParams, Variant).length ==
            __traits(variantParamNames, Variant).length);
    }
}