struct S
{
    int opApply(int delegate(string) dg)
    {
        return 0;
    }
}
shared static this()
{
    foreach (_; S())
    {
        return;
    }
}
