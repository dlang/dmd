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

struct Sys
{
    static import core.stdc.stdlib;

    alias abort = core.stdc.stdlib.abort;
}

debug(PRINTF)
{
    static import core.stdc.stdio;

    void printf(T...)(scope const(char*) fmt, T vals) nothrow @nogc
    {
        int r = core.stdc.stdio.printf(fmt, vals);

        if(r < 0)
            Sys.abort();
    }
}
