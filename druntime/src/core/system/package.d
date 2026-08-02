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
    import core.stdc.stdio;

    alias abort = core.stdc.stdlib.abort;

    // Assumes str is null-terminated string
    static void print(scope const char[] str) nothrow @nogc
    {
        auto r = fputs(str.ptr, stdout);
        if(r < 0)
            Sys.abort();
    }

    //~ void print(T)(scope const char[] str, T vals) nothrow @nogc
    //~ {
        //~ // Assume str is null-terminated string
        //~ auto r = fputs(str.ptr, stdout);
        //~ if(r < 0)
            //~ Sys.abort();
    //~ }

    //~ alias format = snprintf
}

// Special case: we don't have resources to implement mature formatting
// functionality for now just for the sake of using it at debugging
debug
{
    static import core.stdc.stdio;

    alias sprintf = core.stdc.stdio.sprintf;
    alias snprintf = core.stdc.stdio.snprintf;

    void printf(T...)(scope const(char*) fmt, T vals) nothrow @nogc
    {
        int r = core.stdc.stdio.printf(fmt, vals);

        if(r < fmt.length)
            Sys.abort();
    }
}
