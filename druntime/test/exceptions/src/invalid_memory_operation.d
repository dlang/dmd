struct S
{
    ~this()
    {
        new int;
    }
}

void main()
{
    foreach(i; 0 .. 100)
        new S;
}
