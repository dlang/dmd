///
module core.system;

//TODO: package
//package:

struct Mem
{
    import core.stdc.stdlib;

    alias allocateOne = malloc;
    alias allocateFew = (size_t num, size_t size) => allocateOne(num * size);
    static void* allocateOneBlank(size_t size) nothrow @nogc => allocateFewBlank(1, size);
    alias allocateFewBlank = calloc;
    alias reallocate = realloc;
    alias free = core.stdc.stdlib.free;

    alias allocateOnStack = alloca;
}

struct Opt
{
    import core.gc.config: ConfigT;

    alias GcConfig = ConfigT!();
}
