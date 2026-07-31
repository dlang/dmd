///
module core.system;

package:

struct Mem
{
    import core.stdc.stdlib;

    alias allocate = malloc;
    alias reallocate = realloc;
    alias free = core.stdc.stdlib.free;

    static void* allocateBlank(size_t size) nothrow @nogc => calloc(1, size);

    /+
    static void* allocateBlank(size_t size) nothrow @nogc
    {
        ubyte* p = cast(ubyte*) allocate(size);
        p[0 .. size] = 0;
        return cast(void*) p;
    }
    +/
}
