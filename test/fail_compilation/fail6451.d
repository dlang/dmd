
version(X86_64)
{
    void error(...){}
}
else
{
    static assert(0);
}

