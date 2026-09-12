///
module core.internal.config.memory;

// libc version
version (all)
{
    import core.stdc.stdlib;

    alias allocateOne = malloc;
    alias allocateFew = (size_t num, size_t size) nothrow @nogc => allocateOne(num * size);
    void* allocateOneBlank(size_t size) nothrow @nogc => allocateFewBlank(1, size);
    alias allocateFewBlank = calloc;
    alias reallocate = realloc;
    alias freeMem = core.stdc.stdlib.free;

    alias allocateOnStack = alloca;
}
