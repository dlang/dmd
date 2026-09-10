void main()
{
    static enum union Value
    {
        case int,
        case string;
    }

    Value value = 1;
    assert(value.__tag == 0);
}