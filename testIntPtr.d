char* initPtr()
{
    return cast(char*) size_t.max;
}

static assert(cast(size_t)initPtr() == size_t.max);
