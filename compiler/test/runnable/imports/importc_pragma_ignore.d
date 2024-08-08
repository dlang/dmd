module importc_pragma_ignore;

int foo()
{
    return 1;
}

alias bar = _bar;

int _bar(int x)
{
    return x * 2;
}

void* memset(void* destination, int value, size_t count)
{
    foreach (index; 0 .. count)
    {
        // Zero the memory so we can tell the difference between this and the actual memset.
        (cast(ubyte*) destination)[index] = 0;
    }

    return destination;
}
