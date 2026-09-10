enum union Pointers
{
    case int*,
    case bool*,
}

int classify(Pointers pointers)
{
    return switch (pointers)
    {
        case int* => 1,
        case bool* => 2,
    };
}

void main()
{
    int value;
    auto pointers = Pointers(&value);
    assert(classify(pointers) == 1);
}