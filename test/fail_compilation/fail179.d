
void main()
{
    int x = 3;
    final px = &x;
    *px = 4;
    auto ppx = &px;
    **ppx = 5;
}
