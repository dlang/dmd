// Test static foreach and static if inside switch expressions

template AliasSeq(T...)
{
    alias AliasSeq = T;
}

template Filter(alias Pred, T...)
{
    static if (T.length == 0)
        alias Filter = AliasSeq!();
    else static if (Pred!(T[0]))
        alias Filter = AliasSeq!(T[0], Filter!(Pred, T[1 .. $]));
    else
        alias Filter = Filter!(Pred, T[1 .. $]);
}

enum union DynamicNumber
{
    case error();
    case int;
    case double;
}

DynamicNumber sum(DynamicNumber a, DynamicNumber b) @safe
{
    enum isBare(alias V) = __traits(variantKind, V) == "bare";
    alias NumericVariants = Filter!(isBare, __traits(allVariants, DynamicNumber));

    return switch (a)
    {
        case error() => a,
        static foreach (V1; NumericVariants)
            case V1 v1 => switch (b)
            {
                case error() => b,
                static foreach (V2; NumericVariants)
                    case V2 v2 => DynamicNumber(v1 + v2)
            }
    };
}

// Test braced static foreach and static if / else
enum union Shape
{
    case Circle(double);
    case Rect(double, double);
    case Point();
}

double area(Shape s)
{
    return switch (s)
    {
        static foreach (T; __traits(allVariants, Shape))
        {
            static if (__traits(identifier, T) == "Circle")
            {
                case Circle(r) => 3.14159 * r * r,
            }
            else static if (__traits(identifier, T) == "Rect")
            {
                case Rect(w, h) => w * h,
            }
            else
            {
                // Optional trailing delimiter before right curly
                case Point() => 0.0
            }
        }
    };
}

void test()
{
    DynamicNumber a = DynamicNumber(10);
    DynamicNumber b = DynamicNumber(20.5);
    DynamicNumber c = sum(a, b);

    bool ok = switch (c)
    {
        case double d => (d == 30.5),
        default => false,
    };
    assert(ok);

    Shape sh = Shape.Rect(3.0, 4.0);
    assert(area(sh) == 12.0);

    // Verify CTFE evaluation
    static assert({
        DynamicNumber x = DynamicNumber(5);
        DynamicNumber y = DynamicNumber(15);
        DynamicNumber z = sum(x, y);
        return switch (z)
        {
            case int i => (i == 20),
            default => false,
        };
    }());

    static assert(area(Shape.Rect(5.0, 2.0)) == 10.0);
}
