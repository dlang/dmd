enum union Value
{
    case Unit(),
    case Number(int),
}

string describe()
{
    return switch (Value.Unit)
    {
        case Unit => "unit",
        case Number => "number",
    };
}

static assert(describe() == "unit");