/*
 currently fails with extra safety checks
 PERMUTE_FIXME_ARGS: -preview=dip1000
*/

struct Cache
{
    ubyte[1] v;

    ubyte[] set(ubyte[1] v) return
    {
        return this.v[] = v[];
    }
}
