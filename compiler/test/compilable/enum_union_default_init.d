enum union Value
{
    case Number(int),
}

void main()
{
    Value value = Value.init;
    assert(value.__tag == 0);
}