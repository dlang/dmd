struct S
{
    ~this()
    {
        new int;
    }
}

void main()
{
    new S;
}
