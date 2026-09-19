///
module core.internal.config;

struct Sys
{
    static import core.stdc.stdlib;
    import core.stdc.stdio;

    alias abort = core.stdc.stdlib.abort;

    static void print(scope const char[] str) nothrow @nogc
    {
        // This is a silly approach, but it's a simple way to print non-null-terminated strings
        // TODO: implement using write() or so
        foreach(c; str)
        {
            auto r = fputc(c, stdout);
            if(r == EOF)
                Sys.abort();
        }
    }

    /// C-formatted print
    static void printf(T...)(scope const char[] fmt, T vals) nothrow @nogc
    {
        static assert(T.length > 0);

        int r = core.stdc.stdio.printf(fmt.ptr, vals);
        if(r < fmt.length)
            Sys.abort();
    }
}
