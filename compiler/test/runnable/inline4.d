import imports.inline4a;

auto anonclass()
{
    return new class {
        pragma(inline, true)
        final size_t foo()
        {
            return value();
        }
    };
}

void main()
{
    size_t var;

    foreach (d; Data("string"))
    {
        var = d.length();
    }

    assert(var == 6);

    var = anonclass().foo();

    assert(var == 10);

    auto nested = (size_t i) {
        return i - value();
    };

    var = nested(var);

    assert(var == 0);
}
