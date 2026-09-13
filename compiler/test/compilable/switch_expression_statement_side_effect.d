enum union Value
{
    case Unit(),
    case Number(int),
}

void consume()
{
}

void main()
{
    switch (Value.Unit)
    {
        case Unit value => "unit",
        case Number value => { consume(); return "number"; }(),
    }
}