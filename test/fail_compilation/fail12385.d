class C
{
    int x = 0;
}

enum E : immutable (C)
{
    a = new immutable C(),
}

void main()
{
    E.a.x = 1;
}
