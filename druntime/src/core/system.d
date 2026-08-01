///
module core.system;

//TODO: package
//package:

struct Mem
{
    import core.stdc.stdlib;

    alias allocate = malloc;
    alias reallocate = realloc;
    alias free = core.stdc.stdlib.free;
    static void* allocateBlank(size_t size) nothrow @nogc => calloc(1, size);

    alias allocateOnStack = alloca;
}
