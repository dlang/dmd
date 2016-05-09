// PERMUTE_ARGS:

/*
Each of the version identifiers below specifies a combination
of pointer size and machine word size. This test will verify
that the set identifier matches the actual pointer size.
*/

version (D_IP32)
{
    static assert (size_t.sizeof == 4);
    enum dip32 = 1;
}
else
    enum dip32 = 0;

version (D_X32)
{
    static assert (size_t.sizeof == 4);
    enum dx32 = 1;
}
else
    enum dx32 = 0;

version (D_LP64)
{
    static assert (size_t.sizeof == 8);
    enum dlp64 = 1;
}
else
    enum dlp64 = 0;

// one and only one should be set at a time:
static assert ((dip32 + dx32 + dlp64) == 1);
