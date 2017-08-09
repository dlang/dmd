uint[] assignSlice(uint from, uint to, uint[] stuff)
{
    uint[] slice;
    slice.length = to + 4;
    foreach (uint i; 0 .. to + 4)
    {
        slice[i] = i + 1;
    }

    slice[from .. to] = stuff[];
    return slice;
}
pragma(msg, assignSlice(1,4, [0,9,2,4]));
// static assert(assignSlice(1, 4, [9, 8, 7]) == [1, 9, 8, 7, 5, 6, 7, 8]);
static assert(!__traits(newCTFEGaveUp));
