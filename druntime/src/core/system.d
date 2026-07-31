///
module core.system;

package:

static struct Mem
{
    import core.stdc.stdlib;

    alias reallocate = realloc;
}
