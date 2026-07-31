///
module core.system;

package:

static struct Mem
{
    import core.stdc.stdlib;

    alias allocate = malloc;
    alias reallocate = realloc;
    alias free = core.stdc.stdlib.free;
}
