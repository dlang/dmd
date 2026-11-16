// https://github.com/dlang/dmd/issues/24262

void test24262()
{
    auto bytes = cast(byte[4])0;
    auto ints = cast(int[2])0L;
    auto shorts = cast(ushort[2])1;
    alias Bytes = ubyte[8];
    auto aliasArray = cast(Bytes)1UL;
}
