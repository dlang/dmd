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
        case Unit => consume(),
        case Number value => consume(),
    }

    switch (0)
    {
        case 0:
            break;
        default:
            break;
    }
}