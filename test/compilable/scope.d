/*
 currently fails with extra safety checks
 PERMUTE_FIXME_ARGS: -transition=safe
*/

struct Cache
{
    ubyte[1] v;

    ubyte[] set(ubyte[1] v)
    {
        return this.v[] = v[];
    }
}
