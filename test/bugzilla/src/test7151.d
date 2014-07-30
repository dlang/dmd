bool test()
{
    auto a = new Object;
    return a == a && a != new Object;
}
void main()
{
    static assert(test());
}
