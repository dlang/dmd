// note: not actually imported, just built and linked against

extern (C)
{
    extern int x;
}

shared static this()
{
    assert(x == 3);
}
